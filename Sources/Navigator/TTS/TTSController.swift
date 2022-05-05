//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
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

    public class func canSpeak(_ publication: Publication) -> Bool {
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
            if oldValue != isPlaying {
                DispatchQueue.main.async { [self] in
                    delegate?.ttsController(self, playingDidChange: isPlaying)
                }
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

    private func play(_ utterance: TTSUtterance) {
        DispatchQueue.main.async { [self] in
            delegate?.ttsController(self, willStartSpeaking: utterance)
            isPlaying = true
            engine.speak(utterance)
        }
    }

    public func pause() {
        isPlaying = false
        engine.stop()
    }

    public func next() {
        queue.async { [self] in
            do {
                guard let utterance = try nextUtterance(direction: .forward) else {
                    isPlaying = false
                    return
                }
                if !utterance.text.contains(where: { $0.isLetter || $0.isNumber }) {
                    next()
                    return
                }
                play(utterance)

            } catch {
                DispatchQueue.main.async {
                    delegate?.ttsController(self, didReceiveError: error)
                }
            }
        }
    }

    // MARK: - Utterances

    private var contentIterator: ContentIterator? {
        willSet { contentIterator?.close() }
    }

    private enum Direction {
        case forward, backward
    }

    private var speakingUtteranceIndex: Int?
    private var utterances: [TTSUtterance] = []

    private var currentUtterance: TTSUtterance? {
        speakingUtteranceIndex.map { utterances[$0] }
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
            return [utterance(text: description, locator: content.locator)]

        case .text(spans: let spans, style: _):
            return spans.enumerated().map { offset, span in
                utterance(
                    text: span.text,
                    locator: span.locator,
                    language: span.language,
                    postDelay: (offset == spans.count - 1) ? 0.4 : 0
                )
            }
        }
    }

    private func utterance(text: String, locator: Locator, language: String? = nil, postDelay: TimeInterval = 0) -> TTSUtterance {
        TTSUtterance(
            text: text,
            locator: locator,
            language: language ?? defaultLanguage,
            pitch: config.pitch,
            rate: config.rate,
            postDelay: postDelay
        )
    }

    private var defaultLanguage: String {
        config.defaultLanguage
            ?? publication.metadata.languages.first
            ?? AVSpeechSynthesisVoice.currentLanguageCode()
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

public protocol TTSEngineDelegate: AnyObject {
    func ttsEngine(_ engine: TTSEngine, willSpeakRangeAt locator: Locator, of utterance: TTSUtterance)
    func ttsEngine(_ engine: TTSEngine, didFinish utterance: TTSUtterance)
}

public protocol TTSEngine: AnyObject {
    var defaultRate: Double? { get }
    var defaultPitch: Double? { get }
    var delegate: TTSEngineDelegate? { get set }

    func speak(_ utterance: TTSUtterance)
    func stop()
}

public class AVTTSEngine: NSObject, TTSEngine, AVSpeechSynthesizerDelegate, Loggable {

    public lazy var defaultRate: Double? =
        avRateRange.percentageForValue(Double(AVSpeechUtteranceDefaultSpeechRate))

    /// Range of valid values for an AVUtterance rate.
    ///
    /// > The speech rate is a decimal representation within the range of `AVSpeechUtteranceMinimumSpeechRate` and
    /// > `AVSpeechUtteranceMaximumSpeechRate`. Lower values correspond to slower speech, and higher values correspond to
    /// > faster speech. The default value is `AVSpeechUtteranceDefaultSpeechRate`.
    /// > https://developer.apple.com/documentation/avfaudio/avspeechutterance/1619708-rate
    private let avRateRange =
        Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate)

    public lazy var defaultPitch: Double? =
        avPitchRange.percentageForValue(1.0)

    /// Range of valid values for an AVUtterance pitch.
    ///
    /// > Before enqueing the utterance, set this property to a value within the range of 0.5 for lower pitch to 2.0 for
    /// > higher pitch. The default value is 1.0.
    /// > https://developer.apple.com/documentation/avfaudio/avspeechutterance/1619683-pitchmultiplier
    private let avPitchRange = 0.5...2.0

    public weak var delegate: TTSEngineDelegate?

    private let synthesizer = AVSpeechSynthesizer()

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func speak(_ utterance: TTSUtterance) {
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(avUtterance(from: utterance))
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func avUtterance(from utterance: TTSUtterance) -> AVSpeechUtterance {
        let avUtterance = AVUtterance(utterance: utterance)
        if let rate = utterance.rate ?? defaultRate {
            avUtterance.rate = Float(avRateRange.valueForPercentage(rate))
        }
        if let pitch = utterance.pitch ?? defaultPitch {
            avUtterance.pitchMultiplier = Float(avPitchRange.valueForPercentage(pitch))
        }
        avUtterance.postUtteranceDelay = utterance.postDelay
        avUtterance.voice = AVSpeechSynthesisVoice(language: utterance.language)
        return avUtterance
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard let utterance = utterance as? AVUtterance else {
            return
        }
        delegate?.ttsEngine(self, didFinish: utterance.utterance)
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance avUtterance: AVSpeechUtterance) {
        guard
            let delegate = delegate,
            let range = Range(characterRange)
        else {
            return
        }
//        controller?.notifySpeakingRange(range)
    }

    private class AVUtterance: AVSpeechUtterance {
        let utterance: TTSUtterance

        init(utterance: TTSUtterance) {
            self.utterance = utterance
            super.init(string: utterance.text)
        }

        required init?(coder: NSCoder) {
            fatalError("Not supported")
        }
    }
}