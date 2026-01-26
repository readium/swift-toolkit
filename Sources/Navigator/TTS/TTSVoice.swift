//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import ReadiumShared

/// Represents a voice provided by the TTS engine which can speak an utterance.
public struct TTSVoice: Hashable {
    public enum Gender: Hashable {
        case female, male, unspecified
    }

    public enum Quality: Hashable {
        case lower, low, medium, high, higher
    }

    /// Unique and stable identifier for this voice. Can be used to store and retrieve the voice from the user
    /// preferences.
    public let identifier: String

    /// Human-friendly name for this voice.
    public let name: String

    /// Language (and region) this voice belongs to.
    public let language: Language

    /// Voice gender.
    public let gender: Gender

    /// Voice quality.
    public let quality: Quality?

    public init(
        identifier: String,
        language: Language,
        name: String,
        gender: Gender,
        quality: Quality?
    ) {
        self.identifier = identifier
        self.language = language
        self.name = name
        self.gender = gender
        self.quality = quality
    }
}

public extension [TTSVoice] {
    /// Filter voices by language.
    ///
    /// If the input language includes a region (e.g., "en-US"), only voices
    /// with that exact language and region combination will be returned.
    /// If the input language has no region (e.g., "en"), all voices matching
    /// the base language will be returned, regardless of their region.
    func filterByLanguage(_ language: Language) -> [TTSVoice] {
        if language.region != nil {
            // Exact match: language code and region must both match
            return filter { $0.language == language }
        } else {
            // Base language match: filter by language code only, ignoring region
            return filter { $0.language.removingRegion() == language }
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
    func sorted(
        preferredRegions: [Language.Region]? = nil,
        displayLocale: Locale = .current
    ) -> [TTSVoice] {
        let languagesAndRegions: [(language: Language, region: Language.Region?)] =
            map { ($0.language.removingRegion(), $0.language.region) }

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
                    ($0.localizedName(in: displayLocale) ?? $0.code) < ($1.localizedName(in: displayLocale) ?? $1.code)
                }
                )

                ordered = ordered.removingDuplicates()

                // Assign priorities: lower Int = higher priority
                let priorities = Dictionary(uniqueKeysWithValues:
                    ordered.enumerated().map { idx, region in (region, idx) }
                )

                return (language, priorities)
            })

        func sortKey(for voice: TTSVoice) -> (
            language: String,
            region: Int,
            quality: Int,
            gender: Int,
            name: String
        ) {
            let language = voice.language.removingRegion()

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
                language: language.localizedLanguage(in: displayLocale) ?? voice.language.code.bcp47,
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
            .compactMap { ReadiumShared.Language(code: .bcp47($0)).region }
    }
}

// Default region per base language.
// Source: https://github.com/HadrienGardeur/web-speech-recommended-voices
private let defaultRegionByLanguage: [Language.Code: Language.Region] = [
    .bcp47("ar"): "SA",
    .bcp47("bg"): "BG",
    .bcp47("bho"): "IN",
    .bcp47("bn"): "IN",
    .bcp47("ca"): "ES",
    .bcp47("cmn"): "CN",
    .bcp47("cs"): "CZ",
    .bcp47("da"): "DK",
    .bcp47("de"): "DE",
    .bcp47("el"): "GR",
    .bcp47("en"): "US",
    .bcp47("es"): "ES",
    .bcp47("eu"): "ES",
    .bcp47("fa"): "IR",
    .bcp47("fi"): "FI",
    .bcp47("fr"): "FR",
    .bcp47("gl"): "ES",
    .bcp47("he"): "IL",
    .bcp47("hi"): "IN",
    .bcp47("hr"): "HR",
    .bcp47("hu"): "HU",
    .bcp47("id"): "ID",
    .bcp47("it"): "IT",
    .bcp47("ja"): "JP",
    .bcp47("kn"): "IN",
    .bcp47("ko"): "KR",
    .bcp47("mr"): "IN",
    .bcp47("ms"): "MY",
    .bcp47("nb"): "NO",
    .bcp47("nl"): "NL",
    .bcp47("pl"): "PL",
    .bcp47("pt"): "BR",
    .bcp47("ro"): "RO",
    .bcp47("ru"): "RU",
    .bcp47("sk"): "SK",
    .bcp47("sl"): "SI",
    .bcp47("sv"): "SE",
    .bcp47("ta"): "IN",
    .bcp47("te"): "IN",
    .bcp47("th"): "TH",
    .bcp47("tr"): "TR",
    .bcp47("uk"): "UA",
    .bcp47("vi"): "VN",
    .bcp47("wuu"): "CN",
    .bcp47("yue"): "HK",
]

// Quality order priority: higher to lower
private let qualityPriorities: [TTSVoice.Quality: Int] = [
    .higher: 0,
    .high: 1,
    .medium: 2,
    .low: 3,
    .lower: 4,
]

// Gender order priority: female > male > unspecified
private let genderPriorities: [TTSVoice.Gender: Int] = [
    .female: 0,
    .male: 1,
    .unspecified: 2,
]
