//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import ReadiumShared

/// Represents a voice provided by the TTS engine which can speak an utterance.
public struct TTSVoice: Hashable, Sendable, Identifiable {
    /// Unique and stable identifier for a voice.
    public struct ID: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral {
        public let rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        public init(rawValue: String) {
            self.init(rawValue)
        }

        public init(stringLiteral value: String) {
            self.init(value)
        }
    }

    public enum Gender: Hashable, Sendable {
        case female, male, unspecified
    }

    public enum Quality: Hashable, Sendable {
        case lower, low, medium, high, higher
    }

    /// Unique and stable identifier for this voice.
    public let id: ID

    @available(*, unavailable, message: "Use `id.rawValue` instead")
    public var identifier: String {
        fatalError()
    }

    /// Human-friendly name for this voice.
    public let name: String

    /// Language (and region) this voice belongs to.
    public let language: Language

    /// Voice gender.
    public let gender: Gender

    /// Voice quality.
    public let quality: Quality?

    public init(
        id: ID,
        language: Language,
        name: String,
        gender: Gender,
        quality: Quality?
    ) {
        self.id = id
        self.language = language
        self.name = name
        self.gender = gender
        self.quality = quality
    }

    @available(*, unavailable, message: "Use `init(id:language:name:gender:quality:)` instead")
    public init(
        identifier: String,
        language: Language,
        name: String,
        gender: Gender,
        quality: Quality?
    ) {
        fatalError()
    }
}

public extension [TTSVoice] {
    /// Filter voices by language.
    ///
    /// If the input language includes a region (e.g., "en-US"), only voices
    /// with that exact language and region combination will be returned.
    /// If the input language has no region (e.g., "en"), all voices matching
    /// the primary language will be returned, regardless of their region.
    func filterByLanguage(_ language: Language) -> [TTSVoice] {
        if language.region != nil {
            // Exact match: language code and region must both match
            return filter { $0.language == language }
        } else {
            // Primary language match: filter by language code only, ignoring region
            return filter { $0.language.primaryLanguage == language }
        }
    }

    /// Sort the voices according to the following specification:
    /// 1. Order by region:
    ///   - Use the regions of the devices at the top of the list.
    ///   - If missing, use a default region per language.
    ///   - Then order the remaining regions alphabetically.
    /// 2. Order by voice quality from highest to lowest.
    /// 3. Order by voice gender: female > male > unspecified.
    /// 4. Order by voice name alphabetically.
    ///
    /// - Parameter preferredRegions: Regions to list first, e.g. `GB` or `419`.
    func sorted(
        preferredRegions: [Language.Region]? = nil,
        displayLocale: Locale = .current
    ) -> [TTSVoice] {
        let languagesAndRegions: [(language: Language, region: Language.Region?)] =
            map { ($0.language.primaryLanguage, $0.language.region) }

        let regionsByLanguage: [Language: Set<Language.Region>] =
            Dictionary(grouping: languagesAndRegions, by: \.language)
                .mapValues { value in
                    Set(value.compactMap(\.region))
                }

        let preferredRegions = preferredRegions ?? Locale.preferredRegions

        let regionPrioritiesByLanguage: [Language: [Language.Region: Int]] =
            Dictionary(uniqueKeysWithValues: regionsByLanguage.map { language, regions in
                var ordered: [Language.Region] = []

                // 1. Start with device-preferred regions.
                ordered.append(
                    contentsOf: preferredRegions.filter { regions.contains($0) }
                )

                // 2. Default region for the language, if any.
                if let defaultRegion = defaultRegionByLanguage[language.code] {
                    ordered.append(defaultRegion)
                }

                // 3. Add remaining regions ordered by localized name.
                ordered.append(contentsOf: regions.sorted {
                    ($0.localizedName(in: displayLocale) ?? $0.rawValue) < ($1.localizedName(in: displayLocale) ?? $1.rawValue)
                })

                ordered = ordered.removingDuplicates()

                // Assign priorities: lower Int = higher priority
                let priorities = Dictionary(uniqueKeysWithValues:
                    ordered.enumerated().map { idx, region in (region, idx) })

                return (language, priorities)
            })

        func sortKey(for voice: TTSVoice) -> (
            language: String,
            region: Int,
            quality: Int,
            gender: Int,
            name: String
        ) {
            let language = voice.language.primaryLanguage

            let regionPriority: Int =
                if
                    let region = voice.language.region,
                    let regionPriorities = regionPrioritiesByLanguage[language]
                {
                    regionPriorities[region] ?? .max
                } else {
                    .max
                }

            return (
                language: language.localizedLanguage(in: displayLocale) ?? voice.language.tag,
                region: regionPriority,
                quality: voice.quality.flatMap { qualityPriorities[$0] } ?? .max,
                gender: genderPriorities[voice.gender] ?? .max,
                name: voice.name
            )
        }

        let voicesWithKeys = map { voice in
            (voice: voice, key: sortKey(for: voice))
        }

        return voicesWithKeys.sorted { a, b in
            let ka = a.key
            let kb = b.key

            if ka.language != kb.language {
                return ka.language < kb.language
            }
            if ka.region != kb.region {
                return ka.region < kb.region
            }
            if ka.quality != kb.quality {
                return ka.quality < kb.quality
            }
            if ka.gender != kb.gender {
                return ka.gender < kb.gender
            }

            return ka.name.localizedCaseInsensitiveCompare(kb.name) == .orderedAscending
        }.map(\.voice)
    }
}

private extension Locale {
    static var preferredRegions: [ReadiumShared.Language.Region] {
        preferredLanguages
            .compactMap { ReadiumShared.Language($0).region }
    }
}

// Default region per primary language.
// Source: https://github.com/HadrienGardeur/web-speech-recommended-voices
private let defaultRegionByLanguage: [Language.Code: Language.Region] = [
    "ar": "SA",
    "bg": "BG",
    "bho": "IN",
    "bn": "IN",
    "ca": "ES",
    "cmn": "CN",
    "cs": "CZ",
    "da": "DK",
    "de": "DE",
    "el": "GR",
    "en": "US",
    "es": "ES",
    "eu": "ES",
    "fa": "IR",
    "fi": "FI",
    "fr": "FR",
    "gl": "ES",
    "he": "IL",
    "hi": "IN",
    "hr": "HR",
    "hu": "HU",
    "id": "ID",
    "it": "IT",
    "ja": "JP",
    "kn": "IN",
    "ko": "KR",
    "mr": "IN",
    "ms": "MY",
    "nb": "NO",
    "nl": "NL",
    "pl": "PL",
    "pt": "BR",
    "ro": "RO",
    "ru": "RU",
    "sk": "SK",
    "sl": "SI",
    "sv": "SE",
    "ta": "IN",
    "te": "IN",
    "th": "TH",
    "tr": "TR",
    "uk": "UA",
    "vi": "VN",
    "wuu": "CN",
    "yue": "HK",
]

/// Quality order priority: higher to lower
private let qualityPriorities: [TTSVoice.Quality: Int] = [
    .higher: 0,
    .high: 1,
    .medium: 2,
    .low: 3,
    .lower: 4,
]

/// Gender order priority: female > male > unspecified
private let genderPriorities: [TTSVoice.Gender: Int] = [
    .female: 0,
    .male: 1,
    .unspecified: 2,
]
