//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import R2Shared

public protocol TTSControllerDelegate: AnyObject {
    func ttsController(_ ttsController: TTSController, stateDidChange state: TTSController.State)

    func ttsController(_ ttsController: TTSController, didStartSpeaking text: String, locale: String, at locator: Locator)
    func ttsController(_ ttsController: TTSController, didStartSpeakingRangeAt locator: Locator)
}

public extension TTSControllerDelegate {
    func ttsController(_ ttsController: TTSController, stateDidChange state: TTSController.State) {}
    func ttsController(_ ttsController: TTSController, didStartSpeaking text: String, locale: String, at locator: Locator) {}
    func ttsController(_ ttsController: TTSController, didStartSpeakingRangeAt locator: Locator) {}
}

public class TTSController {

    public struct Configuration {
        public var defaultLanguage: String?
        public var rate: Double

        public init(defaultLanguage: String? = nil, rate: Double = defaultRate) {
            self.defaultLanguage = defaultLanguage
            self.rate = rate
        }

        public static let defaultRate: Double = Double(AVSpeechUtteranceDefaultSpeechRate)
        public static let minimumRate: Double = Double(AVSpeechUtteranceMinimumSpeechRate)
        public static let maximumRate: Double = Double(AVSpeechUtteranceMaximumSpeechRate)
    }

    private let publication: Publication
    public var config: Configuration
    public weak var delegate: TTSControllerDelegate?

    private let queue = DispatchQueue.global(qos: .userInitiated)

    public init(publication: Publication, config: Configuration = Configuration(), delegate: TTSControllerDelegate? = nil) {
        self.publication = publication
        self.config = config
        self.delegate = delegate

        adapter.controller = self
    }

    public enum State {
        case stopped, speaking, paused, failure(Error)
    }

    public var state: State {
        if let error = error {
            return .failure(error)
        } else {
            return adapter.state
        }
    }

    private func notifyStateUpdate() {
        delegate?.ttsController(self, stateDidChange: state)
    }

    private var error: Error? {
        didSet {
            if oldValue != nil || error != nil {
                notifyStateUpdate()
            }
        }
    }

    public func playPause(from start: Locator? = nil) {
        if case .speaking = state {
            pause()
        } else {
            play(from: start)
        }
    }

    public func play(from start: Locator? = nil) {
        if start == nil {
            switch state {
            case .stopped:
                break
            case .paused:
                if adapter.continue() {
                    return
                }
            case .speaking:
                return
            case .failure:
                break
            }
        }

        speakingUtteranceIndex = nil
        utterances = []
        contentIterator = publication.contentIterator(from: start)
        next()
    }

    public func pause() {
        adapter.pause()
    }

    public func next() {
        queue.async { [self] in
            error = nil
            do {
                guard let utterance = try nextUtterance(direction: .forward) else {
                    return
                }
                adapter.speak(utterance)
            } catch {
                self.error = error
            }
        }
    }

    // MARK: - Utterances

    private var contentIterator: ContentIterator? {
        willSet { contentIterator?.close() }
    }

    private struct Utterance {
        let text: String
        let locator: Locator
        var language: String? = nil
        var postDelay: TimeInterval? = nil
    }

    private enum Direction {
        case forward, backward
    }

    private var speakingUtteranceIndex: Int?
    private var utterances: [Utterance] = []

    private func nextUtterance(direction: Direction) throws -> Utterance? {
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

    private func utterances(from content: Content) -> [Utterance] {
        switch content.data {
        case .audio(target: _):
            return []

        case .image(target: _, description: let description):
            guard let description = description, !description.isEmpty else {
                return []
            }
            return [Utterance(text: description, locator: content.locator)]

        case .text(spans: let spans, style: let style):
            return spans.enumerated().map { offset, span in
                Utterance(
                    text: span.text,
                    locator: span.locator,
                    language: span.language,
                    postDelay: (offset == spans.count - 1) ? 0.4 : nil
                )
            }
        }
    }

    // MARK: – Speech Synthesizer

    private let adapter = SpeechSynthesizerAdapter()

    private var defaultLanguage: String {
        config.defaultLanguage
            ?? publication.metadata.languages.first
            ?? AVSpeechSynthesisVoice.currentLanguageCode()
    }

    private class SpeechSynthesizerAdapter: NSObject, AVSpeechSynthesizerDelegate {
        let synthesizer = AVSpeechSynthesizer()
        weak var controller: TTSController?

        override init() {
            super.init()
            synthesizer.delegate = self
        }

        var state: State {
            if synthesizer.isPaused {
                return .paused
            } else if synthesizer.isSpeaking {
                return .speaking
            } else {
                return .stopped
            }
        }

        func pause() {
            synthesizer.pauseSpeaking(at: .word)
        }

        func `continue`() -> Bool {
            synthesizer.continueSpeaking()
        }

        func speak(_ utterance: Utterance) {
            guard let controller = controller else {
                return
            }
            let avUtterance = AVSpeechUtterance(string: utterance.text)
            avUtterance.rate = Float(controller.config.rate)
            avUtterance.postUtteranceDelay = utterance.postDelay ?? 0
            avUtterance.voice = AVSpeechSynthesisVoice(language: utterance.language ?? controller.defaultLanguage)
            synthesizer.speak(avUtterance)
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
            controller?.notifyStateUpdate()
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
            controller?.notifyStateUpdate()
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
            controller?.notifyStateUpdate()
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            controller?.notifyStateUpdate()
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            controller?.next()
        }
    }
}