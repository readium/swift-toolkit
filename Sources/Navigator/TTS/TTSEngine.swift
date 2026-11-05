//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A text-to-speech engine synthesizes text utterances (e.g. sentence).
///
/// Implement this interface to support third-party engines with
/// ``PublicationSpeechSynthesizer``.
@MainActor
public protocol TTSEngine: AnyObject {
    /// List of available synthesizer voices.
    var availableVoices: [TTSVoice] { get }

    /// Returns the voice with the given `id`, if it exists.
    func voice(withID id: TTSVoice.ID) -> TTSVoice?

    /// Synthesizes the given `utterance` and returns its status.
    ///
    /// `onSpeakRange` is called repeatedly while the engine plays portions (e.g. words) of the utterance.
    func speak(
        _ utterance: TTSUtterance,
        onSpeakRange: @escaping (Range<String.Index>) -> Void
    ) async -> Result<Void, TTSError>
}

public extension TTSEngine {
    func voice(withID id: TTSVoice.ID) -> TTSVoice? {
        availableVoices.first { $0.id == id }
    }

    @available(*, unavailable, renamed: "voice(withID:)")
    func voiceWithIdentifier(_ identifier: String) -> TTSVoice? {
        fatalError()
    }
}

public enum TTSError: Error, Sendable {
    /// Tried to synthesize an utterance with an unsupported language.
    case languageNotSupported(language: Language, cause: (any Error)?)

    /// Other engine-specific errors.
    case other(any Error)
}

/// An utterance is an arbitrary text (e.g. sentence) that can be synthesized by the TTS engine.
public struct TTSUtterance: Sendable {
    /// Text to be spoken.
    public let text: String

    /// Delay before speaking the utterance, in seconds.
    public let delay: TimeInterval

    /// Language of the text.
    public let language: Language

    /// Voice selected to speak the text. When `nil`, the engine uses its
    /// default voice for the `language`.
    public let voice: TTSVoice?

    @available(*, unavailable, message: "Use `voice` and `language` instead")
    public var voiceOrLanguage: Either<TTSVoice, Language> {
        fatalError()
    }

    /// Multiplier of the normal speaking speed of the engine (1.0).
    ///
    /// The speed is approximate, and the engine clamps the values outside its supported range.
    public let speed: Double

    /// Multiplier of the normal voice pitch of the engine (1.0).
    ///
    /// The engine clamps the values outside its supported range.
    public let pitch: Double

    /// Whether the engine uses the voice selected by the user in the
    /// accessibility settings of the device for the `language`, instead of
    /// `voice`.
    ///
    /// Only the voice is affected, the `speed` and `pitch` still apply.
    public let prefersAssistiveTechnologyVoice: Bool

    public init(
        text: String,
        delay: TimeInterval = 0,
        language: Language,
        voice: TTSVoice? = nil,
        speed: Double = 1.0,
        pitch: Double = 1.0,
        prefersAssistiveTechnologyVoice: Bool = false
    ) {
        self.text = text
        self.delay = delay
        self.language = language
        self.voice = voice
        self.speed = speed
        self.pitch = pitch
        self.prefersAssistiveTechnologyVoice = prefersAssistiveTechnologyVoice
    }
}
