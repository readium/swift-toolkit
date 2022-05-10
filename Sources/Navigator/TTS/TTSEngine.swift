//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import R2Shared

public protocol TTSEngineDelegate: AnyObject {
    func ttsEngine(_ engine: TTSEngine, willSpeakRangeAt locator: Locator, of utterance: TTSUtterance)
    func ttsEngine(_ engine: TTSEngine, didFinish utterance: TTSUtterance)
}

public protocol TTSEngine: AnyObject {
    var defaultLanguage: String? { get }
    var defaultRate: Double? { get }
    var defaultPitch: Double? { get }
    var delegate: TTSEngineDelegate? { get set }

    func speak(_ utterance: TTSUtterance)
    func stop()
}

public class AVTTSEngine: NSObject, TTSEngine, AVSpeechSynthesizerDelegate, Loggable {

    public var defaultLanguage: String? {
        AVSpeechSynthesisVoice.currentLanguageCode()
    }

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
