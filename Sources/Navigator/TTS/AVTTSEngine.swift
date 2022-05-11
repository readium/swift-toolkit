//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import R2Shared

public class AVTTSEngine: NSObject, TTSEngine, AVSpeechSynthesizerDelegate, Loggable {

    /// Range of valid values for an AVUtterance rate.
    ///
    /// > The speech rate is a decimal representation within the range of `AVSpeechUtteranceMinimumSpeechRate` and
    /// > `AVSpeechUtteranceMaximumSpeechRate`. Lower values correspond to slower speech, and higher values correspond to
    /// > faster speech. The default value is `AVSpeechUtteranceDefaultSpeechRate`.
    /// > https://developer.apple.com/documentation/avfaudio/avspeechutterance/1619708-rate
    private let avRateRange =
        Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate)

    /// Range of valid values for an AVUtterance pitch.
    ///
    /// > Before enqueuing the utterance, set this property to a value within the range of 0.5 for lower pitch to 2.0 for
    /// > higher pitch. The default value is 1.0.
    /// > https://developer.apple.com/documentation/avfaudio/avspeechutterance/1619683-pitchmultiplier
    private let avPitchRange = 0.5...2.0

    public let defaultConfig: TTSConfiguration
    public var config: TTSConfiguration

    public weak var delegate: TTSEngineDelegate?

    private let synthesizer = AVSpeechSynthesizer()

    public override init() {
        let config = TTSConfiguration(
            defaultLanguage: Language(code: .bcp47(AVSpeechSynthesisVoice.currentLanguageCode())),
            rate: avRateRange.percentageForValue(Double(AVSpeechUtteranceDefaultSpeechRate)),
            pitch: avPitchRange.percentageForValue(1.0)
        )

        self.defaultConfig = config
        self.config = config

        super.init()
        synthesizer.delegate = self
    }

    public lazy var availableVoices: [TTSVoice] =
        AVSpeechSynthesisVoice.speechVoices().map { v in
            TTSVoice(
                identifier: v.identifier,
                language: Language(code: .bcp47(v.language)),
                name: v.name,
                gender: .init(voice: v),
                quality: .init(voice: v)
            )
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
        avUtterance.rate = Float(avRateRange.valueForPercentage(config.rate))
        avUtterance.pitchMultiplier = Float(avPitchRange.valueForPercentage(config.pitch))
        avUtterance.preUtteranceDelay = utterance.delay
        avUtterance.postUtteranceDelay = config.delay
        avUtterance.voice = voice(for: utterance)
        return avUtterance
    }

    private func voice(for utterance: TTSUtterance) -> AVSpeechSynthesisVoice? {
        let language = utterance.language ?? config.defaultLanguage
        if let voice = config.voice, voice.language.removingRegion() == language.removingRegion() {
            return AVSpeechSynthesisVoice(identifier: voice.identifier)
        } else {
            return AVSpeechSynthesisVoice(language: language)
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard let utterance = (utterance as? AVUtterance)?.utterance else {
            return
        }
        delegate?.ttsEngine(self, didFinish: utterance)
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance avUtterance: AVSpeechUtterance) {
        guard
            let delegate = delegate,
            let utterance = (avUtterance as? AVUtterance)?.utterance,
            let highlight = utterance.locator.text.highlight,
            let range = Range(characterRange, in: highlight)
        else {
            return
        }

        let rangeLocator = utterance.locator.copy(
            text: { text in text = text[range] }
        )
        delegate.ttsEngine(self, willSpeakRangeAt: rangeLocator, of: utterance)
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

private extension TTSVoice.Gender {
    init(voice: AVSpeechSynthesisVoice) {
        if #available(iOS 13.0, *) {
            switch voice.gender {
            case .unspecified:
                self = .unspecified
            case .male:
                self = .male
            case .female:
                self = .female
            @unknown default:
                self = .unspecified
            }
        } else {
            self = .unspecified
        }
    }
}

private extension TTSVoice.Quality {
    init?(voice: AVSpeechSynthesisVoice) {
        switch voice.quality {
        case .default:
            self = .medium
        case .enhanced:
            self = .high
        @unknown default:
            return nil
        }
    }
}

private extension AVSpeechSynthesisVoice {
    convenience init?(language: Language) {
        self.init(language: language.code.bcp47)
    }
}