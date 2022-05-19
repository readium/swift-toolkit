//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

public protocol TTSControllerDelegate: AnyObject {
    func ttsController(_ ttsController: TTSController, playingDidChange isPlaying: Bool)

    func ttsController(_ ttsController: TTSController, willStartSpeaking utterance: TTSUtterance)
    func ttsController(_ ttsController: TTSController, willSpeakRangeAt locator: Locator, of utterance: TTSUtterance)

    func ttsController(_ ttsController: TTSController, didReceiveError error: Error)
}

public extension TTSControllerDelegate {
    func ttsController(_ ttsController: TTSController, playingDidChange isPlaying: Bool) {}
    func ttsController(_ ttsController: TTSController, willStartSpeaking utterance: TTSUtterance) {}
    func ttsController(_ ttsController: TTSController, willSpeakRangeAt locator: Locator, of utterance: TTSUtterance) {}
}

public struct TTSUtterance: Equatable {
    public let text: String
    public let locator: Locator
    public let language: Language?
    public let delay: TimeInterval
}

public class TTSController: Loggable, TTSEngineDelegate {
    public typealias TokenizerFactory = (_ language: Language?) -> ContentTokenizer

    public static func canPlay(_ publication: Publication) -> Bool {
        publication.isContentIterable
    }

    public var defaultConfig: TTSConfiguration {
        engine.defaultConfig
    }

    public var config: TTSConfiguration {
        get { engine.config }
        set { engine.config = newValue }
    }

    public var availableVoices: [TTSVoice] {
        engine.availableVoices
    }

    public func voiceWithIdentifier(_ id: String) -> TTSVoice? {
        engine.voiceWithIdentifier(id)
    }

    public weak var delegate: TTSControllerDelegate?

    private let publication: Publication
    private let engine: TTSEngine
    private let makeTokenizer: TokenizerFactory
    private let queue: DispatchQueue = .global(qos: .userInitiated)

    public init(
        publication: Publication,
        engine: TTSEngine = AVTTSEngine(),
        makeTokenizer: TokenizerFactory? = nil,
        delegate: TTSControllerDelegate? = nil
    ) {
        precondition(publication.isContentIterable, "The Publication must be iterable to be used with TTSController")

        self.delegate = delegate
        self.publication = publication
        self.engine = engine
        self.makeTokenizer = { language in
            makeTextContentTokenizer(
                unit: .sentence,
                language: language
            )
        }

        if let language = publication.metadata.language {
            engine.config.defaultLanguage = language
        }
        engine.delegate = self
    }

    deinit {
        engine.stop()
        contentIterator?.close()
    }

    public var isPlaying: Bool = false {
        didSet {
            precondition(Thread.isMainThread, "TTSController.isPlaying must be mutated from the main thread")
            if oldValue != isPlaying {
                delegate?.ttsController(self, playingDidChange: isPlaying)
            }
        }
    }

    public func playPause(from start: Locator? = nil) {
        if isPlaying {
            pause()
        } else {
            play(from: start)
        }
    }

    public func pause() {
        precondition(Thread.isMainThread, "TTSController.pause() must be called from the main thread")
        isPlaying = false
        engine.stop()
    }

    public func play(from start: Locator? = nil) {
        if start != nil {
            speakingUtteranceIndex = nil
            utterances = []
            contentIterator = publication.contentIterator(from: start)
        }

        if contentIterator == nil {
            contentIterator = publication.contentIterator(from: nil)
        }

        if let utterance = currentUtterance {
            play(utterance)
        } else {
            next()
        }
    }

    public func previous() {
        playNextUtterance(direction: .backward)
    }

    public func next() {
        playNextUtterance(direction: .forward)
    }

    private enum Direction {
        case forward, backward
    }

    private var contentIterator: ContentIterator? {
        willSet { contentIterator?.close() }
    }

    private var speakingUtteranceIndex: Int?
    private var utterances: [TTSUtterance] = []

    private var currentUtterance: TTSUtterance? {
        speakingUtteranceIndex.map { utterances[$0] }
    }

    private func playNextUtterance(direction: Direction) {
        queue.async { [self] in
            do {
                let utterance = try nextUtterance(direction: direction)
                DispatchQueue.main.async {
                    if let utterance = utterance {
                        play(utterance)
                    } else {
                        isPlaying = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    delegate?.ttsController(self, didReceiveError: error)
                }
            }
        }
    }

    private func play(_ utterance: TTSUtterance) {
        precondition(Thread.isMainThread, "TTSController.play() must be called from the main thread")

        delegate?.ttsController(self, willStartSpeaking: utterance)
        isPlaying = true
        engine.speak(utterance)
    }

    private func nextUtterance(direction: Direction) throws -> TTSUtterance? {
        guard let nextIndex = nextUtteranceIndex(direction: direction) else {
            if try loadNextUtterances(direction: direction) {
                return try nextUtterance(direction: direction)
            } else {
                return nil
            }
        }
        speakingUtteranceIndex = nextIndex
        return utterances[nextIndex]
    }

    private func nextUtteranceIndex(direction: Direction) -> Int? {
        let index: Int = {
            switch direction {
            case .forward:
                return (speakingUtteranceIndex ?? -1) + 1
            case .backward:
                return (speakingUtteranceIndex ?? utterances.count) - 1
            }
        }()
        guard utterances.indices.contains(index) else {
            return  nil
        }
        return index
    }

    private func loadNextUtterances(direction: Direction) throws -> Bool {
        speakingUtteranceIndex = nil
        utterances = []

        guard let content: Content = try {
            switch direction {
            case .forward:
                return try contentIterator?.next()
            case .backward:
                return try contentIterator?.previous()
            }
        }() else {
            return false
        }

        utterances = tokenize(content, with: makeTokenizer(nil))
            .flatMap { utterances(from: $0) }

        guard !utterances.isEmpty else {
            return try loadNextUtterances(direction: direction)
        }

        return true
    }

    private func utterances(from content: Content) -> [TTSUtterance] {
        switch content.data {
        case .audio(target: _):
            return []

        case .image(target: _, description: let description):
            guard let description = description, !description.isEmpty else {
                return []
            }
            return Array(ofNotNil: utterance(text: description, locator: content.locator))

        case .text(spans: let spans, style: _):
            return spans
                .enumerated()
                .compactMap { offset, span in
                    utterance(
                        text: span.text,
                        locator: span.locator,
                        language: span.language,
                        delay: (offset == 0) ? 0.4 : 0
                    )
                }
        }
    }

    private func utterance(text: String, locator: Locator, language: Language? = nil, delay: TimeInterval = 0) -> TTSUtterance? {
        guard text.contains(where: { $0.isLetter || $0.isNumber }) else {
            return nil
        }
        return TTSUtterance(
            text: text,
            locator: locator,
            language: language.takeIf { $0 != publication.metadata.language },
            delay: delay
        )
    }

    private func tokenize(_ content: Content, with tokenizer: ContentTokenizer) -> [Content] {
        do {
            return try tokenizer(content)
        } catch {
            log(.error, error)
            return [content]
        }
    }

    // MARK: - TTSEngineDelegate

    public func ttsEngine(_ engine: TTSEngine, didStopAfterLastUtterance utterance: TTSUtterance) {
        if isPlaying {
            next()
        }
    }

    public func ttsEngine(_ engine: TTSEngine, willSpeakRangeAt locator: Locator, of utterance: TTSUtterance) {
        DispatchQueue.main.async { [self] in
            delegate?.ttsController(self, willSpeakRangeAt: locator, of: utterance)
        }
    }
}
