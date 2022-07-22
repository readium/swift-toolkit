//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import R2Shared

/// Implementation of a `TTSEngine` using Apple AVFoundation's `AVSpeechSynthesizer`.
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
    private let debug: Bool

    public weak var delegate: TTSEngineDelegate?

    private let synthesizer = AVSpeechSynthesizer()

    /// Creates a new `AVTTSEngine` instance.
    ///
    /// - Parameters:
    ///   - audioSessionConfig: AudioSession configuration used while playing utterances. If `nil`, utterances won't
    ///     play when the app is in the background.
    ///   - debug: Print the state machine transitions.
    public init(
        audioSessionConfig: _AudioSession.Configuration? = .init(
            category: .playback,
            mode: .spokenAudio,
            options: .mixWithOthers
        ),
        debug: Bool = false
    ) {
        let config = TTSConfiguration(
            defaultLanguage: Language(code: .bcp47(AVSpeechSynthesisVoice.currentLanguageCode())),
            rate: avRateRange.percentageForValue(Double(AVSpeechUtteranceDefaultSpeechRate)),
            pitch: avPitchRange.percentageForValue(1.0)
        )

        self.defaultConfig = config
        self.config = config
        self.debug = debug
        self.audioSessionUser = audioSessionConfig.map { AudioSessionUser(config: $0) }

        super.init()
        synthesizer.delegate = self
    }

    public lazy var availableVoices: [TTSVoice] =
        AVSpeechSynthesisVoice.speechVoices()
            .map { TTSVoice(voice: $0) }

    public func voiceWithIdentifier(_ id: String) -> TTSVoice? {
        AVSpeechSynthesisVoice(identifier: id)
            .map { TTSVoice(voice: $0) }
    }

    public func speak(_ utterance: TTSUtterance) {
        on(.play(utterance))
    }

    public func stop() {
        on(.stop)
    }
    
    
    // MARK: AVSpeechSynthesizerDelegate
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard let utterance = (utterance as? AVUtterance)?.utterance else {
            return
        }
        on(.didStart(utterance))
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard let utterance = (utterance as? AVUtterance)?.utterance else {
            return
        }
        on(.didFinish(utterance))
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance avUtterance: AVSpeechUtterance) {
        guard
            let utterance = (avUtterance as? AVUtterance)?.utterance,
            let highlight = utterance.locator.text.highlight,
            let range = Range(characterRange, in: highlight)
        else {
            return
        }

        let rangeLocator = utterance.locator.copy(
            text: { text in text = text[range] }
        )
        on(.willSpeakRange(locator: rangeLocator, utterance: utterance))
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

    
    // MARK: State machine
    
    // Submitting new utterances to `AVSpeechSynthesizer` when the `didStart` or
    // `didFinish` events for the previous utterance were not received triggers
    // a deadlock on iOS 15. The engine ignores the following requests.
    //
    // The following state machine is used to make sure we never send commands
    // to the `AVSpeechSynthesizer` when it's not ready.
    //
    // To visualize it, paste the following dot graph in https://edotor.net
    /*
        digraph {
            {
                stopped [style=filled]
            }

            stopped -> starting [label = "play"]

            starting -> playing [label = "didStart"]
            starting -> stopping [label = "play/stop"]

            playing -> stopped [label = "didFinish"]
            playing -> stopping [label = "play/stop"]
            playing -> playing [label = "willSpeakRange"]

            stopping -> stopping [label = "play/stop"]
            stopping -> stopping [label = "didStart"]
            stopping -> starting [label = "didFinish w/ next"]
            stopping -> stopped [label = "didFinish w/o next"]
        }
     */
    
    /// Represents a state of the TTS engine.
    private enum State: Equatable {
        /// The TTS engine is waiting for the next utterance to play.
        case stopped
        /// A new utterance is being processed by the TTS engine, we wait for didStart.
        case starting(TTSUtterance)
        /// The utterance is currently playing and the engine is ready to process other commands.
        case playing(TTSUtterance)
        /// The engine was stopped while processing the previous utterance, we wait for didStart
        /// and/or didFinish. The queued utterance will be played once the engine is successfully stopped.
        case stopping(TTSUtterance, queued: TTSUtterance?)
        
        mutating func on(_ event: Event) -> Effect? {
            switch (self, event) {
                
            // stopped
                
            case let (.stopped, .play(utterance)):
                self = .starting(utterance)
                return .play(utterance)
                
            // starting
                
            case let (.starting(current), .didStart(started)) where current == started:
                self = .playing(current)
                return nil
                
            case let (.starting(current), .play(next)):
                self = .stopping(current, queued: next)
                return nil
                
            case let (.starting(current), .stop):
                self = .stopping(current, queued: nil)
                return nil
                
            // playing
                
            case let (.playing(current), .didFinish(finished)) where current == finished:
                self = .stopped
                return .notifyDidStopAfterLastUtterance(current)
                
            case let (.playing(current), .play(next)):
                self = .stopping(current, queued: next)
                return .stop
                
            case let (.playing(current), .stop):
                self = .stopping(current, queued: nil)
                return .stop
                
            case let (.playing(current), .willSpeakRange(locator: Locator, utterance: speaking)) where current == speaking:
                return .notifyWillSpeakRange(locator: Locator, utterance: current)
                
            // stopping
                
            case let (.stopping(current, queued: next), .didStart(started)) where current == started:
                self = .stopping(current, queued: next)
                return .stop
                
            case let (.stopping(current, queued: next), .didFinish(finished)) where current == finished:
                if let next = next {
                    self = .starting(next)
                    return .play(next)
                } else {
                    self = .stopped
                    return .notifyDidStopAfterLastUtterance(current)
                }
                
            case let (.stopping(current, queued: _), .play(next)):
                self = .stopping(current, queued: next)
                return nil
                
            case let (.stopping(current, queued: _), .stop):
                self = .stopping(current, queued: nil)
                return nil
                
                
            default:
                return nil
            }
        }
    }
    
    /// State machine events triggered by the `AVSpeechSynthesizer` or the client
    /// of `AVTTSEngine`.
    private enum Event: Equatable {
        // AVTTSEngine commands
        case play(TTSUtterance)
        case stop
        
        // AVSpeechSynthesizer delegate events
        case didStart(TTSUtterance)
        case willSpeakRange(locator: Locator, utterance: TTSUtterance)
        case didFinish(TTSUtterance)
    }
    
    /// State machine side effects triggered by a state transition from an event.
    private enum Effect: Equatable {
        // Ask `AVSpeechSynthesizer` to play the utterance.
        case play(TTSUtterance)
        // Ask `AVSpeechSynthesizer` to stop the playback.
        case stop
        
        // Send notifications to our delegate.
        case notifyWillSpeakRange(locator: Locator, utterance: TTSUtterance)
        case notifyDidStopAfterLastUtterance(TTSUtterance)
    }
    
    private var state: State = .stopped {
        didSet {
            if (debug) {
                log(.debug, "* \(state)")
            }
        }
    }
    
    /// Raises a TTS event triggering a state change and handles its side effects.
    private func on(_ event: Event) {
        assert(Thread.isMainThread, "Raising AVTTSEngine events must be done from the main thread")
             
        if (debug) {
            log(.debug, "-> on \(event)")
        }
        
        if let effect = state.on(event) {
            handle(effect)
        }
    }
    
    /// Handles a state machine side effect.
    private func handle(_ effect: Effect) {
        switch effect {
            
        case let .play(utterance):
            synthesizer.speak(avUtterance(from: utterance))

            if let user = audioSessionUser {
                _AudioSession.shared.start(with: user)
            }

        case .stop:
            synthesizer.stopSpeaking(at: .immediate)
            
        case let .notifyWillSpeakRange(locator: Locator, utterance: utterance):
            delegate?.ttsEngine(self, willSpeakRangeAt: Locator, of: utterance)
            
        case let .notifyDidStopAfterLastUtterance(utterance):
            delegate?.ttsEngine(self, didStopAfterLastUtterance: utterance)
        }
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

    // MARK: - Audio session

    private let audioSessionUser: AudioSessionUser?

    private final class AudioSessionUser: R2Shared._AudioSessionUser {
        let audioConfiguration: _AudioSession.Configuration

        init(config: _AudioSession.Configuration) {
            self.audioConfiguration = config
        }

        deinit {
            _AudioSession.shared.end(for: self)
        }

        func play() {}
    }
}

private extension TTSVoice {
    init(voice: AVSpeechSynthesisVoice) {
        self.init(
            identifier: voice.identifier,
            language: Language(code: .bcp47(voice.language)),
            name: voice.name,
            gender: Gender(voice: voice),
            quality: Quality(voice: voice)
        )
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
