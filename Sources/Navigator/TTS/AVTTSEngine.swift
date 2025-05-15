//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import ReadiumShared

public protocol AVTTSEngineDelegate: AnyObject {
    /// Called when the engine created a new utterance to be played.
    /// You can customize additional properties of the utterance.
    func avTTSEngine(_ engine: AVTTSEngine, didCreateUtterance utterance: AVSpeechUtterance)
}

/// Implementation of a `TTSEngine` using Apple AVFoundation's `AVSpeechSynthesizer`.
public class AVTTSEngine: NSObject, TTSEngine, AVSpeechSynthesizerDelegate, Loggable {
    /// Range of valid values for an AVUtterance rate.
    ///
    /// > The speech rate is a decimal representation within the range of `AVSpeechUtteranceMinimumSpeechRate` and
    /// > `AVSpeechUtteranceMaximumSpeechRate`. Lower values correspond to slower speech, and higher values correspond to
    /// > faster speech. The default value is `AVSpeechUtteranceDefaultSpeechRate`.
    /// > https://developer.apple.com/documentation/avfaudio/avspeechutterance/1619708-rate
    private static let avRateRange =
        Double(AVSpeechUtteranceMinimumSpeechRate) ... Double(AVSpeechUtteranceMaximumSpeechRate)

    /// Range of valid values for an AVUtterance pitch.
    ///
    /// > Before enqueuing the utterance, set this property to a value within the range of 0.5 for lower pitch to 2.0 for
    /// > higher pitch. The default value is 1.0.
    /// > https://developer.apple.com/documentation/avfaudio/avspeechutterance/1619683-pitchmultiplier
    private static let avPitchRange = 0.5 ... 2.0

    public weak var delegate: AVTTSEngineDelegate?

    private let debug: Bool = false
    private let synthesizer = AVSpeechSynthesizer()

    /// Creates a new `AVTTSEngine` instance.
    public init(
        delegate: AVTTSEngineDelegate? = nil
    ) {
        self.delegate = delegate

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

    @MainActor
    public func speak(
        _ utterance: TTSUtterance,
        onSpeakRange: @escaping (Range<String.Index>) -> Void
    ) async -> Result<Void, TTSError> {
        let task = Task(
            utterance: utterance,
            onSpeakRange: onSpeakRange
        )

        return await withTaskCancellationHandler {
            await withCheckedContinuation {
                task.continuation = $0
                on(.play(task))
            }
        } onCancel: {
            task.cancel()
            on(.stop(task))
        }
    }

    private class Task: Equatable, CustomStringConvertible {
        let utterance: TTSUtterance
        private let onSpeakRange: (Range<String.Index>) -> Void
        var continuation: CheckedContinuation<Result<Void, TTSError>, Never>!
        private(set) var isCancelled: Bool = false

        init(utterance: TTSUtterance, onSpeakRange: @escaping (Range<String.Index>) -> Void) {
            self.utterance = utterance
            self.onSpeakRange = onSpeakRange
        }

        var description: String {
            utterance.text
        }

        static func == (lhs: Task, rhs: Task) -> Bool {
            ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
        }

        func onSpeakRange(_ range: Range<String.Index>) {
            guard !isCancelled else {
                return
            }
            onSpeakRange(range)
        }

        func finish() {
            continuation.resume(returning: .success(()))
        }

        func cancel() {
            isCancelled = true
        }
    }

    private func taskUtterance(with task: Task) -> TaskUtterance {
        let utter = TaskUtterance(task: task)
//        utter.rate = rateMultiplierToAVRate(task.utterance.rateMultiplier)
//        utter.pitchMultiplier = Float(task.utterance.pitchMultiplier)
        utter.preUtteranceDelay = task.utterance.delay
        utter.voice = voice(for: task.utterance)
        delegate?.avTTSEngine(self, didCreateUtterance: utter)
        return utter
    }

    private class TaskUtterance: AVSpeechUtterance {
        let task: Task

        init(task: Task) {
            self.task = task
            super.init(string: task.utterance.text)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("Not supported")
        }
    }

    // MARK: AVSpeechSynthesizerDelegate

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard let task = (utterance as? TaskUtterance)?.task else {
            return
        }
        on(.didStart(task))
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        guard let task = (utterance as? TaskUtterance)?.task else {
            return
        }
        on(.didFinish(task))
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard let task = (utterance as? TaskUtterance)?.task else {
            return
        }
        on(.didFinish(task))
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance avUtterance: AVSpeechUtterance) {
        guard
            let task = (avUtterance as? TaskUtterance)?.task,
            characterRange.upperBound <= task.utterance.text.count,
            let range = Range(characterRange, in: task.utterance.text)
        else {
            return
        }

        on(.willSpeakRange(range, task: task))
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
        case starting(Task)
        /// The utterance is currently playing and the engine is ready to process other commands.
        case playing(Task)
        /// The engine was stopped while processing the previous utterance, we wait for didStart
        /// and/or didFinish. The queued utterance will be played once the engine is successfully stopped.
        case stopping(Task, queued: Task?)
    }

    /// State machine events triggered by the `AVSpeechSynthesizer` or the client
    /// of `AVTTSEngine`.
    private enum Event: Equatable {
        // AVTTSEngine commands
        case play(Task)
        case stop(Task)

        // AVSpeechSynthesizer delegate events
        case didStart(Task)
        case willSpeakRange(Range<String.Index>, task: Task)
        case didFinish(Task)
    }

    private var state: State = .stopped {
        didSet {
            if debug {
                log(.debug, "* \(state)")
            }
        }
    }

    /// Raises a TTS event triggering a state change and handles its side effects.
    private func on(_ event: Event) {
        assert(Thread.isMainThread, "Raising AVTTSEngine events must be done from the main thread")

        if debug {
            log(.debug, "-> on \(event)")
        }

        switch (state, event) {
        // stopped
        case let (.stopped, .play(task)):
            state = .starting(task)
            startEngine(with: task)

        // starting

        case let (.starting(current), .didStart(started)) where current == started:
            state = .playing(current)

        case let (.starting(current), .play(next)):
            state = .stopping(current, queued: next)

        case let (.starting(current), .stop(toStop)) where current == toStop:
            state = .stopping(current, queued: nil)

        // playing

        case let (.playing(current), .didFinish(finished)) where current == finished:
            state = .stopped

            current.finish()

        case let (.playing(current), .play(next)):
            state = .stopping(current, queued: next)
            stopEngine()

        case let (.playing(current), .stop(toStop)) where current == toStop:
            state = .stopping(current, queued: nil)
            stopEngine()

        case let (.playing(current), .willSpeakRange(range, task: speaking)) where current == speaking:
            current.onSpeakRange(range)

        // stopping

        case let (.stopping(current, queued: next), .didStart(started)) where current == started:
            state = .stopping(current, queued: next)
            stopEngine()

        case let (.stopping(current, queued: next), .didFinish(finished)) where current == finished:
            if let next = next, !next.isCancelled {
                state = .starting(next)
                startEngine(with: next)
            } else {
                state = .stopped
            }

            current.finish()

        case let (.stopping(current, queued: _), .play(next)):
            state = .stopping(current, queued: next)

        case let (.stopping(current, queued: _), .stop(toStop)) where current == toStop:
            state = .stopping(current, queued: nil)

        default:
            break
        }
    }

    private func startEngine(with task: Task) {
        synthesizer.speak(taskUtterance(with: task))
    }

    private func stopEngine() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func voice(for utterance: TTSUtterance) -> AVSpeechSynthesisVoice? {
        switch utterance.voiceOrLanguage {
        case let .left(voice):
            return AVSpeechSynthesisVoice(identifier: voice.identifier)
        case let .right(language):
            return AVSpeechSynthesisVoice(language: language)
        }
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
        #if swift(>=5.7)
            case .premium:
                self = .high
        #endif
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
