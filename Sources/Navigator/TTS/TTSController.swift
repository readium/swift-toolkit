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
    public let language: String?
    public let pitch: Double?
    public let rate: Double?
    public let postDelay: TimeInterval
}

public class TTSController: Loggable, TTSEngineDelegate {

    public struct Configuration {
        public var defaultLanguage: String?
        public var rate: Double
        public var pitch: Double

        public init(
            defaultLanguage: String?,
            rate: Double,
            pitch: Double
        ) {
            self.defaultLanguage = defaultLanguage
            self.rate = rate
            self.pitch = pitch
        }
    }

    public static func canPlay(_ publication: Publication) -> Bool {
        publication.isContentIterable
    }

    public let defaultRate: Double
    public let defaultPitch: Double
    public var config: Configuration
    public weak var delegate: TTSControllerDelegate?

    private let publication: Publication
    private let engine: TTSEngine
    private let queue: DispatchQueue = .global(qos: .userInitiated)

    public init(publication: Publication, engine: TTSEngine = AVTTSEngine(), delegate: TTSControllerDelegate? = nil) {
        precondition(publication.isContentIterable, "The Publication must be iterable to be used with TTSController")

        self.defaultRate = engine.defaultRate ?? 0.5
        self.defaultPitch = engine.defaultPitch ?? 0.5
        self.config = Configuration(defaultLanguage: nil, rate: defaultRate, pitch: defaultPitch)
        self.delegate = delegate
        self.publication = publication
        self.engine = engine

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

        utterances = utterances(from: content)
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
            return spans.enumerated().compactMap { offset, span in
                utterance(
                    text: span.text,
                    locator: span.locator,
                    language: span.language,
                    postDelay: (offset == spans.count - 1) ? 0.4 : 0
                )
            }
        }
    }

    private func utterance(text: String, locator: Locator, language: String? = nil, postDelay: TimeInterval = 0) -> TTSUtterance? {
        guard text.contains(where: { $0.isLetter || $0.isNumber }) else {
            return nil
        }
        return TTSUtterance(
            text: text,
            locator: locator,
            language: language ?? defaultLanguage,
            pitch: config.pitch,
            rate: config.rate,
            postDelay: postDelay
        )
    }

    private var defaultLanguage: String? {
        config.defaultLanguage
            ?? publication.metadata.languages.first
            ?? engine.defaultLanguage
    }

    // MARK: - TTSEngineDelegate

    public func ttsEngine(_ engine: TTSEngine, didFinish utterance: TTSUtterance) {
        if isPlaying && currentUtterance == utterance {
            next()
        }
    }

    public func ttsEngine(_ engine: TTSEngine, willSpeakRangeAt locator: Locator, of utterance: TTSUtterance) {
        DispatchQueue.main.async { [self] in
            delegate?.ttsController(self, willSpeakRangeAt: locator, of: utterance)
        }
    }
}