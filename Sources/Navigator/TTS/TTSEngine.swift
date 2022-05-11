//
//  Copyright 2021 Readium Foundation. All rights reserved.
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

    func speak(_ utterance: TTSUtterance)
    func stop()
}

public protocol TTSEngineDelegate: AnyObject {
    func ttsEngine(_ engine: TTSEngine, willSpeakRangeAt locator: Locator, of utterance: TTSUtterance)
    func ttsEngine(_ engine: TTSEngine, didFinish utterance: TTSUtterance)
}

public struct TTSConfiguration {
    public var defaultLanguage: Language
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
        self.defaultLanguage = defaultLanguage
        self.rate = rate
        self.pitch = pitch
        self.voice = voice
        self.delay = delay
    }
}

public struct TTSVoice {
    public enum Gender {
        case female, male, unspecified
    }

    public enum Quality {
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
