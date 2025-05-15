//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A text-to-speech engine synthesizes text utterances (e.g. sentence).
///
/// Implement this interface to support third-party engines with
/// ``PublicationSpeechSynthesizer``.
public protocol TTSEngine: AnyObject {
    /// List of available synthesizer voices.
    var availableVoices: [TTSVoice] { get }

    /// Returns the voice with given identifier, if it exists.
    func voiceWithIdentifier(_ identifier: String) -> TTSVoice?

    /// Synthesizes the given `utterance` and returns its status.
    ///
    /// `onSpeakRange` is called repeatedly while the engine plays portions (e.g. words) of the utterance.
    func speak(
        _ utterance: TTSUtterance,
        onSpeakRange: @escaping (Range<String.Index>) -> Void
    ) async -> Result<Void, TTSError>
}

public extension TTSEngine {
    func voiceWithIdentifier(_ identifier: String) -> TTSVoice? {
        availableVoices.first { $0.identifier == identifier }
    }
}

public enum TTSError: Error {
    /// Tried to synthesize an utterance with an unsupported language.
    case languageNotSupported(language: Language, cause: Error?)

    /// Other engine-specific errors.
    case other(Error)
}

/// An utterance is an arbitrary text (e.g. sentence) that can be synthesized by the TTS engine.
public struct TTSUtterance {
    /// Text to be spoken.
    public let text: String

    /// Delay before speaking the utterance, in seconds.
    public let delay: TimeInterval

    /// Either an explicit voice or the language of the text. If a language is provided, the default voice for this
    /// language will be used.
    public let voiceOrLanguage: Either<TTSVoice, Language>

    public var language: Language {
        switch voiceOrLanguage {
        case let .left(voice):
            return voice.language
        case let .right(language):
            return language
        }
    }
}

/// Represents a voice provided by the TTS engine which can speak an utterance.
public struct TTSVoice: Hashable {
    public enum Gender: Hashable {
        case female, male, unspecified
    }

    public enum Quality: Hashable {
        case low, medium, high
    }

    /// Unique and stable identifier for this voice. Can be used to store and retrieve the voice from the user
    /// preferences.
    public let identifier: String

    /// Human-friendly name for this voice, when available.
    public let name: String?

    /// Language (and region) this voice belongs to.
    public let language: Language

    /// Voice gender.
    public let gender: Gender

    /// Voice quality.
    public let quality: Quality?

    public init(identifier: String, language: Language, name: String, gender: Gender, quality: Quality?) {
        self.identifier = identifier
        self.language = language
        self.name = name
        self.gender = gender
        self.quality = quality
    }
}
