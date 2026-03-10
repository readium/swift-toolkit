//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import XCTest

class TTSVoiceTests: XCTestCase {
    private let displayLocale = Locale(identifier: "en-US")

    private func makeVoice(
        identifier: String? = nil,
        language: String,
        name: String? = nil,
        gender: TTSVoice.Gender = .female,
        quality: TTSVoice.Quality? = nil
    ) -> TTSVoice {
        TTSVoice(
            identifier: identifier ?? "voice-\(language)",
            language: Language(code: .bcp47(language)),
            name: name ?? "Voice (\(language))",
            gender: gender,
            quality: quality
        )
    }

    // MARK: - Filtering by Language

    func testFiltersByBaseLanguage() {
        let voices = [
            makeVoice(language: "en-US"),
            makeVoice(language: "en-GB"),
            makeVoice(language: "en"),
            makeVoice(language: "fr-FR"),
            makeVoice(language: "en-CA"),
            makeVoice(language: "de-DE"),
        ]

        let filtered = voices.filterByLanguage(Language(code: .bcp47("en")))

        XCTAssertEqual(filtered.map(\.language.code.bcp47), ["en-US", "en-GB", "en", "en-CA"])
    }

    func testFiltersByExactLanguageAndRegion() {
        let voices = [
            makeVoice(language: "en-US"),
            makeVoice(language: "en-GB"),
            makeVoice(language: "en"),
            makeVoice(language: "fr-FR"),
            makeVoice(language: "en-CA"),
        ]

        let filtered = voices.filterByLanguage(Language(code: .bcp47("en-US")))

        XCTAssertEqual(filtered.map(\.language.code.bcp47), ["en-US"])
    }

    func testFilterByLanguageWithNoMatchesReturnsEmpty() {
        let voices = [
            makeVoice(language: "en-US"),
            makeVoice(language: "en-GB"),
            makeVoice(language: "fr-FR"),
        ]

        let filtered = voices.filterByLanguage(Language(code: .bcp47("de")))

        XCTAssertTrue(filtered.isEmpty)
    }

    func testFilterByLanguageOnEmptyArrayReturnsEmpty() {
        let voices: [TTSVoice] = []

        let filtered = voices.filterByLanguage(Language(code: .bcp47("en")))

        XCTAssertTrue(filtered.isEmpty)
    }

    func testFilterByLanguagePreservesOrder() {
        let voices = [
            makeVoice(identifier: "voice-1", language: "en-GB"),
            makeVoice(identifier: "voice-2", language: "fr-FR"),
            makeVoice(identifier: "voice-3", language: "en-US"),
            makeVoice(identifier: "voice-4", language: "en-CA"),
        ]

        let filtered = voices.filterByLanguage(Language(code: .bcp47("en")))

        XCTAssertEqual(filtered.map(\.identifier), ["voice-1", "voice-3", "voice-4"])
    }

    func testFilterByLanguageWithMultipleMatchesForSameRegion() {
        let voices = [
            makeVoice(identifier: "voice-1", language: "en-US", name: "Voice 1"),
            makeVoice(identifier: "voice-2", language: "en-US", name: "Voice 2"),
            makeVoice(identifier: "voice-3", language: "en-GB", name: "Voice 3"),
            makeVoice(identifier: "voice-4", language: "en-US", name: "Voice 4"),
        ]

        let filtered = voices.filterByLanguage(Language(code: .bcp47("en-US")))

        XCTAssertEqual(filtered.count, 3)
        XCTAssertEqual(filtered.map(\.identifier), ["voice-1", "voice-2", "voice-4"])
    }

    // MARK: - Sorting by Language

    func testSortsByLanguageAlphabetically() {
        let voices = [
            makeVoice(language: "zh-CN"),
            makeVoice(language: "en-US"),
            makeVoice(language: "fr-FR"),
            makeVoice(language: "ar-SA"),
        ]

        let sorted = voices.sorted(displayLocale: displayLocale)

        // Languages should be sorted by their localized names
        XCTAssertEqual(sorted.map(\.language.code.bcp47), [
            "ar-SA",
            "zh-CN",
            "en-US",
            "fr-FR",
        ])
    }

    func testGroupsVoicesByBaseLanguage() {
        let voices = [
            makeVoice(language: "en-GB"),
            makeVoice(language: "fr-CA"),
            makeVoice(language: "en-US"),
            makeVoice(language: "fr-FR"),
        ]

        let sorted = voices.sorted(displayLocale: displayLocale)

        // All English voices should be grouped together, all French together
        let languages = sorted.map { String($0.language.removingRegion().code.bcp47) }
        XCTAssertEqual(languages, ["en", "en", "fr", "fr"])
    }

    // MARK: - Sorting by Region

    func testSortsRegionsByDefaultRegionPriority() {
        let voices = [
            makeVoice(language: "en-AU", quality: .high),
            makeVoice(language: "en-GB", quality: .high),
            makeVoice(language: "en-US", quality: .high),
            makeVoice(language: "en-CA", quality: .high),
        ]

        let sorted = voices.sorted(displayLocale: displayLocale)

        // US should come first, other regions are ordered based on localized
        // names.
        XCTAssertEqual(sorted.map(\.language.code.bcp47), [
            "en-US",
            "en-AU",
            "en-CA",
            "en-GB",
        ])
    }

    func testSortsRegionsUsingPreferredRegions() {
        let voices = [
            makeVoice(language: "en-AU", quality: .high),
            makeVoice(language: "en-GB", quality: .high),
            makeVoice(language: "en-US", quality: .high),
            makeVoice(language: "en-FR", quality: .high),
            makeVoice(language: "en-CA", quality: .high),
        ]

        let sorted = voices.sorted(preferredRegions: ["GB", "AU"], displayLocale: displayLocale)

        // Preferred regions appear first in the given order, then the default
        // region, then the rest ordered alphabetically.
        XCTAssertEqual(sorted.map(\.language.code.bcp47), [
            "en-GB",
            "en-AU",
            "en-US",
            "en-CA",
            "en-FR",
        ])
    }

    func testVoicesWithoutRegionAreSortedLast() {
        let voices = [
            makeVoice(language: "en-US", quality: .high),
            makeVoice(language: "en", quality: .high),
            makeVoice(language: "en-GB", quality: .high),
        ]

        let sorted = voices.sorted()

        // Voice without region should be last.
        XCTAssertEqual(sorted.last?.language.code.bcp47, "en")
    }

    // MARK: - Sorting by Quality

    func testSortsByQualityHigherToLower() {
        let voices = [
            makeVoice(language: "en-US", quality: .low),
            makeVoice(language: "en-US", quality: .higher),
            makeVoice(language: "en-US", quality: .medium),
            makeVoice(language: "en-US", quality: .high),
            makeVoice(language: "en-US", quality: .lower),
        ]

        let sorted = voices.sorted()

        XCTAssertEqual(sorted.map(\.quality), [.higher, .high, .medium, .low, .lower])
    }

    func testVoicesWithoutQualityAreSortedLast() {
        let voices = [
            makeVoice(language: "en-US", quality: .low),
            makeVoice(language: "en-US", quality: nil),
            makeVoice(language: "en-US", quality: .high),
        ]

        let sorted = voices.sorted()

        XCTAssertEqual(sorted.map(\.quality), [.high, .low, nil])
    }

    // MARK: - Sorting by Gender

    func testSortsByGender() {
        let voices = [
            makeVoice(language: "en-US", gender: .unspecified, quality: .high),
            makeVoice(language: "en-US", gender: .male, quality: .high),
            makeVoice(language: "en-US", gender: .female, quality: .high),
        ]

        let sorted = voices.sorted()

        XCTAssertEqual(sorted.map(\.gender), [.female, .male, .unspecified])
    }

    // MARK: - Sorting by Name

    func testSortsByNameAlphabetically() {
        let voices = [
            makeVoice(language: "en-US", name: "zoe", gender: .female, quality: .high),
            makeVoice(language: "en-US", name: "Alice", gender: .female, quality: .high),
            makeVoice(language: "en-US", name: "BOB", gender: .female, quality: .high),
        ]

        let sorted = voices.sorted()

        XCTAssertEqual(sorted.map(\.name), ["Alice", "BOB", "zoe"])
    }

    // MARK: - Multi-level Sorting

    func testComplexSortingScenario() {
        let voices = [
            // French voices
            makeVoice(language: "fr-FR", name: "Marie", gender: .female, quality: .high),
            makeVoice(language: "fr-CA", name: "Sophie", gender: .female, quality: .higher),

            // English voices - US region (default)
            makeVoice(language: "en-US", name: "Alice", gender: .female, quality: .higher),
            makeVoice(language: "en-US", name: "Bob", gender: .male, quality: .higher),
            makeVoice(language: "en-US", name: "Alex", gender: .female, quality: .high),

            // English voices - GB region
            makeVoice(language: "en-GB", name: "Victoria", gender: .female, quality: .higher),

            // English voices - no region
            makeVoice(language: "en", name: "Generic", gender: .female, quality: .higher),
        ]

        let sorted = voices.sorted(displayLocale: displayLocale)

        XCTAssertEqual(sorted.map(\.name), [
            "Alice",
            "Bob",
            "Alex",
            "Victoria",
            "Generic",
            "Marie",
            "Sophie",
        ])
    }

    // MARK: - Edge Cases

    func testEmptyArrayReturnEmptyArray() {
        let voices: [TTSVoice] = []
        let sorted = voices.sorted()
        XCTAssertTrue(sorted.isEmpty)
    }

    func testSingleVoiceReturnsSameVoice() {
        let voices = [makeVoice(language: "en-US")]
        let sorted = voices.sorted()
        XCTAssertEqual(sorted.count, 1)
        XCTAssertEqual(sorted[0].identifier, voices[0].identifier)
    }

    func testIdenticalVoicesPreserveStableOrder() {
        let voices = [
            makeVoice(identifier: "voice-1", language: "en-US", name: "Same", gender: .female, quality: .high),
            makeVoice(identifier: "voice-2", language: "en-US", name: "Same", gender: .female, quality: .high),
            makeVoice(identifier: "voice-3", language: "en-US", name: "Same", gender: .female, quality: .high),
        ]

        let sorted = voices.sorted()

        // Swift's sort is stable, so order should be preserved for identical items
        XCTAssertEqual(sorted.map(\.identifier), ["voice-1", "voice-2", "voice-3"])
    }
}
