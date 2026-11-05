//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumNavigator
import ReadiumShared
import Testing

enum TTSVoiceTests {
    struct FilterByLanguage {
        @Test func filtersByBaseLanguage() {
            let voices = [
                TTSVoice(language: "en-US"),
                TTSVoice(language: "en-GB"),
                TTSVoice(language: "en"),
                TTSVoice(language: "fr-FR"),
                TTSVoice(language: "en-CA"),
                TTSVoice(language: "de-DE"),
            ]

            let filtered = voices.filterByLanguage("en")

            #expect(filtered.map(\.language.code.bcp47) == ["en-US", "en-GB", "en", "en-CA"])
        }

        @Test func filtersByExactLanguageAndRegion() {
            let voices = [
                TTSVoice(language: "en-US"),
                TTSVoice(language: "en-GB"),
                TTSVoice(language: "en"),
                TTSVoice(language: "fr-FR"),
                TTSVoice(language: "en-CA"),
            ]

            let filtered = voices.filterByLanguage("en-US")

            #expect(filtered.map(\.language.code.bcp47) == ["en-US"])
        }

        @Test func withNoMatchesReturnsEmpty() {
            let voices = [
                TTSVoice(language: "en-US"),
                TTSVoice(language: "en-GB"),
                TTSVoice(language: "fr-FR"),
            ]

            let filtered = voices.filterByLanguage("de")

            #expect(filtered.isEmpty)
        }

        @Test func onEmptyArrayReturnsEmpty() {
            let voices: [TTSVoice] = []

            let filtered = voices.filterByLanguage("en")

            #expect(filtered.isEmpty)
        }

        @Test func preservesOrder() {
            let voices = [
                TTSVoice(id: "voice-1", language: "en-GB"),
                TTSVoice(id: "voice-2", language: "fr-FR"),
                TTSVoice(id: "voice-3", language: "en-US"),
                TTSVoice(id: "voice-4", language: "en-CA"),
            ]

            let filtered = voices.filterByLanguage("en")

            #expect(filtered.map(\.id) == ["voice-1", "voice-3", "voice-4"])
        }

        @Test func withMultipleMatchesForSameRegion() {
            let voices = [
                TTSVoice(id: "voice-1", language: "en-US", name: "Voice 1"),
                TTSVoice(id: "voice-2", language: "en-US", name: "Voice 2"),
                TTSVoice(id: "voice-3", language: "en-GB", name: "Voice 3"),
                TTSVoice(id: "voice-4", language: "en-US", name: "Voice 4"),
            ]

            let filtered = voices.filterByLanguage("en-US")

            #expect(filtered.map(\.id) == ["voice-1", "voice-2", "voice-4"])
        }
    }

    struct SortByLanguage {
        @Test func sortsByLanguageAlphabetically() {
            let voices = [
                TTSVoice(language: "zh-CN"),
                TTSVoice(language: "en-US"),
                TTSVoice(language: "fr-FR"),
                TTSVoice(language: "ar-SA"),
            ]

            let sorted = voices.sorted(displayLocale: displayLocale)

            // Languages are sorted by their localized names.
            #expect(sorted.map(\.language.code.bcp47) == [
                "ar-SA",
                "zh-CN",
                "en-US",
                "fr-FR",
            ])
        }

        @Test func groupsVoicesByBaseLanguage() {
            let voices = [
                TTSVoice(language: "en-GB"),
                TTSVoice(language: "fr-CA"),
                TTSVoice(language: "en-US"),
                TTSVoice(language: "fr-FR"),
            ]

            let sorted = voices.sorted(displayLocale: displayLocale)

            #expect(sorted.map { $0.language.removingRegion().code.bcp47 } == ["en", "en", "fr", "fr"])
        }
    }

    struct SortByRegion {
        @Test func sortsRegionsByDefaultRegionPriority() {
            let voices = [
                TTSVoice(language: "en-AU", quality: .high),
                TTSVoice(language: "en-GB", quality: .high),
                TTSVoice(language: "en-US", quality: .high),
                TTSVoice(language: "en-CA", quality: .high),
            ]

            let sorted = voices.sorted(displayLocale: displayLocale)

            // US comes first, the other regions are ordered by their localized
            // names.
            #expect(sorted.map(\.language.code.bcp47) == [
                "en-US",
                "en-AU",
                "en-CA",
                "en-GB",
            ])
        }

        @Test func sortsRegionsUsingPreferredRegions() {
            let voices = [
                TTSVoice(language: "en-AU", quality: .high),
                TTSVoice(language: "en-GB", quality: .high),
                TTSVoice(language: "en-US", quality: .high),
                TTSVoice(language: "en-FR", quality: .high),
                TTSVoice(language: "en-CA", quality: .high),
            ]

            let sorted = voices.sorted(preferredRegions: ["GB", "AU"], displayLocale: displayLocale)

            // Preferred regions appear first in the given order, then the default
            // region, then the rest ordered alphabetically.
            #expect(sorted.map(\.language.code.bcp47) == [
                "en-GB",
                "en-AU",
                "en-US",
                "en-CA",
                "en-FR",
            ])
        }

        @Test func voicesWithoutRegionAreSortedLast() {
            let voices = [
                TTSVoice(language: "en-US", quality: .high),
                TTSVoice(language: "en", quality: .high),
                TTSVoice(language: "en-GB", quality: .high),
            ]

            let sorted = voices.sorted()

            #expect(sorted.last?.language.code.bcp47 == "en")
        }
    }

    struct SortByQuality {
        @Test func sortsByQualityHigherToLower() {
            let voices = [
                TTSVoice(language: "en-US", quality: .low),
                TTSVoice(language: "en-US", quality: .higher),
                TTSVoice(language: "en-US", quality: .medium),
                TTSVoice(language: "en-US", quality: .high),
                TTSVoice(language: "en-US", quality: .lower),
            ]

            let sorted = voices.sorted()

            #expect(sorted.map(\.quality) == [.higher, .high, .medium, .low, .lower])
        }

        @Test func voicesWithoutQualityAreSortedLast() {
            let voices = [
                TTSVoice(language: "en-US", quality: .low),
                TTSVoice(language: "en-US", quality: nil),
                TTSVoice(language: "en-US", quality: .high),
            ]

            let sorted = voices.sorted()

            #expect(sorted.map(\.quality) == [.high, .low, nil])
        }
    }

    struct SortByGender {
        @Test func sortsByGender() {
            let voices = [
                TTSVoice(language: "en-US", gender: .unspecified, quality: .high),
                TTSVoice(language: "en-US", gender: .male, quality: .high),
                TTSVoice(language: "en-US", gender: .female, quality: .high),
            ]

            let sorted = voices.sorted()

            #expect(sorted.map(\.gender) == [.female, .male, .unspecified])
        }
    }

    struct SortByName {
        @Test func sortsByNameAlphabetically() {
            let voices = [
                TTSVoice(language: "en-US", name: "zoe", gender: .female, quality: .high),
                TTSVoice(language: "en-US", name: "Alice", gender: .female, quality: .high),
                TTSVoice(language: "en-US", name: "BOB", gender: .female, quality: .high),
            ]

            let sorted = voices.sorted()

            #expect(sorted.map(\.name) == ["Alice", "BOB", "zoe"])
        }
    }

    struct MultiLevelSort {
        @Test func complexSortingScenario() {
            let voices = [
                // French voices
                TTSVoice(language: "fr-FR", name: "Marie", gender: .female, quality: .high),
                TTSVoice(language: "fr-CA", name: "Sophie", gender: .female, quality: .higher),

                // English voices - US region (default)
                TTSVoice(language: "en-US", name: "Alice", gender: .female, quality: .higher),
                TTSVoice(language: "en-US", name: "Bob", gender: .male, quality: .higher),
                TTSVoice(language: "en-US", name: "Alex", gender: .female, quality: .high),

                // English voices - GB region
                TTSVoice(language: "en-GB", name: "Victoria", gender: .female, quality: .higher),

                // English voices - no region
                TTSVoice(language: "en", name: "Generic", gender: .female, quality: .higher),
            ]

            let sorted = voices.sorted(displayLocale: displayLocale)

            #expect(sorted.map(\.name) == [
                "Alice",
                "Bob",
                "Alex",
                "Victoria",
                "Generic",
                "Marie",
                "Sophie",
            ])
        }
    }

    struct SortEdgeCases {
        @Test func emptyArrayReturnsEmptyArray() {
            let voices: [TTSVoice] = []
            #expect(voices.sorted().isEmpty)
        }

        @Test func singleVoiceReturnsSameVoice() {
            let voices = [TTSVoice(language: "en-US")]
            #expect(voices.sorted().map(\.id) == voices.map(\.id))
        }

        @Test func identicalVoicesPreserveStableOrder() {
            let voices = [
                TTSVoice(id: "voice-1", language: "en-US", name: "Same", gender: .female, quality: .high),
                TTSVoice(id: "voice-2", language: "en-US", name: "Same", gender: .female, quality: .high),
                TTSVoice(id: "voice-3", language: "en-US", name: "Same", gender: .female, quality: .high),
            ]

            let sorted = voices.sorted()

            // The sort is stable, so the order of identical voices is preserved.
            #expect(sorted.map(\.id) == ["voice-1", "voice-2", "voice-3"])
        }
    }
}

// MARK: - Helpers

private let displayLocale = Locale(identifier: "en-US")

private extension TTSVoice {
    init(
        id: ID? = nil,
        language: Language,
        name: String? = nil,
        gender: Gender = .female,
        quality: Quality? = nil
    ) {
        self.init(
            id: id ?? ID("voice-\(language.code.bcp47)"),
            language: language,
            name: name ?? "Voice (\(language.code.bcp47))",
            gender: gender,
            quality: quality
        )
    }
}
