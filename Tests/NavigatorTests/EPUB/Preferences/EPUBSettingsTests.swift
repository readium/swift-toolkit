//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import XCTest

class EPUBSettingsTests: XCTestCase {
    func resolveLayout(
        languages: [String] = [],
        readingProgression: ReadiumShared.ReadingProgression = .auto,
        defaults: EPUBDefaults = EPUBDefaults(),
        preferences: EPUBPreferences = EPUBPreferences()
    ) -> CSSLayout {
        let metadata = Metadata(
            title: "Fake title",
            languages: languages,
            readingProgression: readingProgression
        )

        return EPUBSettings(
            preferences: preferences,
            defaults: defaults,
            metadata: metadata
        ).cssLayout
    }

    func testComputeLayoutWithoutPreferencesOrDefaults() {
        XCTAssertEqual(
            resolveLayout(),
            CSSLayout(language: nil, stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["en"]),
            CSSLayout(language: "en", stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["ar"]),
            CSSLayout(language: "ar", stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["fa"]),
            CSSLayout(language: "fa", stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["he"]),
            CSSLayout(language: "he", stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["ja"]),
            CSSLayout(language: "ja", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["ko"]),
            CSSLayout(language: "ko", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh"]),
            CSSLayout(language: "zh", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-HK"]),
            CSSLayout(language: "zh-HK", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-Hans"]),
            CSSLayout(language: "zh-Hans", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-Hant"]),
            CSSLayout(language: "zh-Hant", stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-TW"]),
            CSSLayout(language: "zh-TW", stylesheets: .cjkVertical, readingProgression: .rtl)
        )
    }

    func testComputeLayoutWithLTRReadingProgression() {
        XCTAssertEqual(
            resolveLayout(readingProgression: .ltr),
            CSSLayout(language: nil, stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["en"], readingProgression: .ltr),
            CSSLayout(language: "en", stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["ar"], readingProgression: .ltr),
            CSSLayout(language: "ar", stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["fa"], readingProgression: .ltr),
            CSSLayout(language: "fa", stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["he"], readingProgression: .ltr),
            CSSLayout(language: "he", stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["ja"], readingProgression: .ltr),
            CSSLayout(language: "ja", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["ko"], readingProgression: .ltr),
            CSSLayout(language: "ko", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh"], readingProgression: .ltr),
            CSSLayout(language: "zh", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-HK"], readingProgression: .ltr),
            CSSLayout(language: "zh-HK", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-Hans"], readingProgression: .ltr),
            CSSLayout(language: "zh-Hans", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-Hant"], readingProgression: .ltr),
            CSSLayout(language: "zh-Hant", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-TW"], readingProgression: .ltr),
            CSSLayout(language: "zh-TW", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
    }

    func testComputeLayoutWithRTLReadingProgression() {
        XCTAssertEqual(
            resolveLayout(readingProgression: .rtl),
            CSSLayout(language: nil, stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["en"], readingProgression: .rtl),
            CSSLayout(language: "en", stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["ar"], readingProgression: .rtl),
            CSSLayout(language: "ar", stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["fa"], readingProgression: .rtl),
            CSSLayout(language: "fa", stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["he"], readingProgression: .rtl),
            CSSLayout(language: "he", stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["ja"], readingProgression: .rtl),
            CSSLayout(language: "ja", stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["ko"], readingProgression: .rtl),
            CSSLayout(language: "ko", stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh"], readingProgression: .rtl),
            CSSLayout(language: "zh", stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-HK"], readingProgression: .rtl),
            CSSLayout(language: "zh-HK", stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-Hans"], readingProgression: .rtl),
            CSSLayout(language: "zh-Hans", stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-Hant"], readingProgression: .rtl),
            CSSLayout(language: "zh-Hant", stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-TW"], readingProgression: .rtl),
            CSSLayout(language: "zh-TW", stylesheets: .cjkVertical, readingProgression: .rtl)
        )
    }

    func testComputeLayoutWithVerticalTextForceEnabled() {
        XCTAssertEqual(
            resolveLayout(preferences: EPUBPreferences(verticalText: true)),
            CSSLayout(language: nil, stylesheets: .cjkVertical, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(readingProgression: .ltr, preferences: EPUBPreferences(verticalText: true)),
            CSSLayout(language: nil, stylesheets: .cjkVertical, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(readingProgression: .rtl, preferences: EPUBPreferences(verticalText: true)),
            CSSLayout(language: nil, stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["en"], readingProgression: .ltr, preferences: EPUBPreferences(verticalText: true)),
            CSSLayout(language: "en", stylesheets: .cjkVertical, readingProgression: .ltr)
        )
    }

    func testComputeLayoutWithVerticalTextForceDisabled() {
        XCTAssertEqual(
            resolveLayout(preferences: EPUBPreferences(verticalText: false)),
            CSSLayout(language: nil, stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(readingProgression: .ltr, preferences: EPUBPreferences(verticalText: false)),
            CSSLayout(language: nil, stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(readingProgression: .rtl, preferences: EPUBPreferences(verticalText: false)),
            CSSLayout(language: nil, stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["en"], readingProgression: .ltr, preferences: EPUBPreferences(verticalText: false)),
            CSSLayout(language: "en", stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["ar"], readingProgression: .rtl, preferences: EPUBPreferences(verticalText: false)),
            CSSLayout(language: "ar", stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["ja"], readingProgression: .ltr, preferences: EPUBPreferences(verticalText: false)),
            CSSLayout(language: "ja", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["ja"], readingProgression: .rtl, preferences: EPUBPreferences(verticalText: false)),
            CSSLayout(language: "ja", stylesheets: .cjkHorizontal, readingProgression: .rtl)
        )
    }

    func testRTLPreferenceTakesPrecedenceOverLTRPublicationMetadata() {
        XCTAssertEqual(
            resolveLayout(readingProgression: .ltr, preferences: EPUBPreferences(readingProgression: .rtl)),
            CSSLayout(language: nil, stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-TW"], readingProgression: .ltr, preferences: EPUBPreferences(readingProgression: .rtl)),
            CSSLayout(language: "zh-TW", stylesheets: .cjkVertical, readingProgression: .rtl)
        )
    }

    func testLTRPreferenceTakesPrecedenceOverRTLPublicationMetadata() {
        XCTAssertEqual(
            resolveLayout(readingProgression: .rtl, preferences: EPUBPreferences(readingProgression: .ltr)),
            CSSLayout(language: nil, stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-TW"], readingProgression: .rtl, preferences: EPUBPreferences(readingProgression: .ltr)),
            CSSLayout(language: "zh-TW", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
    }

    func testLTRPublicationMetadataTakesPrecedenceOverRTLDefault() {
        XCTAssertEqual(
            resolveLayout(readingProgression: .ltr, defaults: EPUBDefaults(readingProgression: .rtl)),
            CSSLayout(language: nil, stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["ja"], readingProgression: .ltr, defaults: EPUBDefaults(readingProgression: .rtl)),
            CSSLayout(language: "ja", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
    }

    func testRTLPublicationMetadataTakesPrecedenceOverLTRDefault() {
        XCTAssertEqual(
            resolveLayout(readingProgression: .rtl, defaults: EPUBDefaults(readingProgression: .ltr)),
            CSSLayout(language: nil, stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-tw"], readingProgression: .rtl, defaults: EPUBDefaults(readingProgression: .ltr)),
            CSSLayout(language: "zh-tw", stylesheets: .cjkVertical, readingProgression: .rtl)
        )
    }

    func testReadingProgressionFallbacksToLTR() {
        XCTAssertEqual(
            resolveLayout(readingProgression: .auto),
            CSSLayout(language: nil, stylesheets: .default, readingProgression: .ltr)
        )
    }

    func testReadingProgressionFallbacksToDefaultReadingProgressionIfThereAreNoLanguagePreferenceOrHint() {
        XCTAssertEqual(
            resolveLayout(readingProgression: .auto, defaults: EPUBDefaults(readingProgression: .rtl)),
            CSSLayout(language: nil, stylesheets: .rtl, readingProgression: .rtl)
        )
    }

    func testLanguageMetadataTakesPrecedenceOverDefaultReadingProgression() {
        XCTAssertEqual(
            resolveLayout(languages: ["en"], readingProgression: .auto, defaults: EPUBDefaults(readingProgression: .rtl)),
            CSSLayout(language: "en", stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh"], readingProgression: .auto, defaults: EPUBDefaults(readingProgression: .rtl)),
            CSSLayout(language: "zh", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
    }

    func testRTLPreferenceTakesPrecedenceOverLanguageMetadata() {
        XCTAssertEqual(
            resolveLayout(languages: ["en"], readingProgression: .auto, preferences: EPUBPreferences(readingProgression: .rtl)),
            CSSLayout(language: "en", stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh"], readingProgression: .auto, preferences: EPUBPreferences(readingProgression: .rtl)),
            CSSLayout(language: "zh", stylesheets: .cjkVertical, readingProgression: .rtl)
        )
    }

    func testLTRPreferenceTakesPrecedenceOverLanguageMetadata() {
        XCTAssertEqual(
            resolveLayout(languages: ["he"], readingProgression: .auto, preferences: EPUBPreferences(readingProgression: .ltr)),
            CSSLayout(language: "he", stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            resolveLayout(languages: ["zh-tw"], readingProgression: .auto, preferences: EPUBPreferences(readingProgression: .ltr)),
            CSSLayout(language: "zh-tw", stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
    }

    func testRTLPreferenceTakesPrecedenceOverLanguagePreference() {
        XCTAssertEqual(
            resolveLayout(preferences: EPUBPreferences(language: "en", readingProgression: .rtl)),
            CSSLayout(language: "en", stylesheets: .rtl, readingProgression: .rtl)
        )
    }

    func testLTRPreferenceTakesPrecedenceOverLanguagePreference() {
        XCTAssertEqual(
            resolveLayout(preferences: EPUBPreferences(language: "he", readingProgression: .ltr)),
            CSSLayout(language: "he", stylesheets: .default, readingProgression: .ltr)
        )
    }

    func testHELanguagePreferenceTakesPrecedenceOverLanguageMetadata() {
        XCTAssertEqual(
            resolveLayout(languages: ["en"], readingProgression: .ltr, preferences: EPUBPreferences(language: "he")),
            CSSLayout(language: "he", stylesheets: .rtl, readingProgression: .rtl)
        )
    }

    func testZHTWLanguagePreferenceTakesPrecedenceOverLanguageMetadata() {
        XCTAssertEqual(
            resolveLayout(languages: ["en"], readingProgression: .ltr, preferences: EPUBPreferences(language: "zh-tw")),
            CSSLayout(language: "zh-tw", stylesheets: .cjkVertical, readingProgression: .rtl)
        )
    }
}
