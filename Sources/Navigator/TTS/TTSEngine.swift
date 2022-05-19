//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

public protocol TTSEngine: AnyObject {
    var defaultConfig: TTSConfiguration { get }
    var config: TTSConfiguration { get set }
    var delegate: TTSEngineDelegate? { get set }
    var availableVoices: [TTSVoice] { get }
    func voiceWithIdentifier(_ id: String) -> TTSVoice?

    func speak(_ utterance: TTSUtterance)
    func stop()
}

public protocol TTSEngineDelegate: AnyObject {
    func ttsEngine(_ engine: TTSEngine, willSpeakRangeAt locator: Locator, of utterance: TTSUtterance)
    func ttsEngine(_ engine: TTSEngine, didStopAfterLastUtterance utterance: TTSUtterance)
}

public struct TTSConfiguration {
    public var defaultLanguage: Language {
        didSet {
            defaultLanguage = defaultLanguage.removingRegion()
            voice = nil
        }
    }
    public var rate: Double
    public var pitch: Double
    public var voice: TTSVoice?
    public var delay: TimeInterval

    public init(
        defaultLanguage: Language,
        rate: Double = 0.5,
        pitch: Double = 0.5,
        voice: TTSVoice? = nil,
        delay: TimeInterval = 0
    ) {
        self.defaultLanguage = defaultLanguage.removingRegion()
        self.rate = rate
        self.pitch = pitch
        self.voice = voice
        self.delay = delay
    }
}

public struct TTSVoice: Hashable {
    public enum Gender: Hashable {
        case female, male, unspecified
    }

    public enum Quality: Hashable {
        case low, medium, high
    }

    public let identifier: String
    public let language: Language
    public let name: String
    public let gender: Gender
    public let quality: Quality?

    public init(identifier: String, language: Language, name: String, gender: Gender, quality: Quality?) {
        self.identifier = identifier
        self.language = language
        self.name = name
        self.gender = gender
        self.quality = quality
    }
}
