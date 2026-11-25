//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum LanguageTests {
    struct Conversion: Sendable, CustomTestStringConvertible {
        let input: String
        let expected: String

        var testDescription: String {
            "\"\(input)\""
        }
    }

    struct Parsing {
        struct Example: Sendable, CustomTestStringConvertible {
            let input: String
            let tag: String
            let code: Language.Code
            var script: Language.Script?
            var region: Language.Region?

            var testDescription: String {
                "\"\(input)\""
            }
        }

        @Test(arguments: [
            Example(input: "en", tag: "en", code: "en"),
            Example(input: "yue", tag: "yue", code: "yue"),
            Example(input: "en-US", tag: "en-US", code: "en", region: "US"),
            Example(input: "zh-Hant", tag: "zh-Hant", code: "zh", script: "Hant"),
            Example(input: "zh-Hant-TW", tag: "zh-Hant-TW", code: "zh", script: "Hant", region: "TW"),
            Example(input: "es-419", tag: "es-419", code: "es", region: "419"),
            // Case and separator variants.
            Example(input: "EN-us", tag: "en-US", code: "en", region: "US"),
            Example(input: "ZH-HANT-tw", tag: "zh-Hant-TW", code: "zh", script: "Hant", region: "TW"),
            Example(input: "zh_hant_TW", tag: "zh-Hant-TW", code: "zh", script: "Hant", region: "TW"),
            // Surrounding whitespaces and `Locale` keywords are ignored.
            Example(input: " en-US ", tag: "en-US", code: "en", region: "US"),
            Example(input: "zh_TW@calendar=roc", tag: "zh-TW", code: "zh", region: "TW"),
            // Up to three extended language subtags are kept in the tag,
            // before the script and region.
            Example(input: "zh-YUE-hk", tag: "zh-yue-HK", code: "zh", region: "HK"),
            Example(input: "zh-yue-Hant-HK", tag: "zh-yue-Hant-HK", code: "zh", script: "Hant", region: "HK"),
            Example(input: "zh-aaa-bbb-ccc-ddd-Hant", tag: "zh-aaa-bbb-ccc-ddd-hant", code: "zh"),
            Example(input: "en-USA", tag: "en-usa", code: "en"),
            // Variants are kept lowercased.
            Example(input: "de-CH-1901", tag: "de-CH-1901", code: "de", region: "CH"),
            Example(input: "sl-Latn-IT-ROZAJ", tag: "sl-Latn-IT-rozaj", code: "sl", script: "Latn", region: "IT"),
            Example(input: "en_US_POSIX", tag: "en-US-posix", code: "en", region: "US"),
            // Other subtags are not read as a script or a region.
            Example(input: "de-1996", tag: "de-1996", code: "de"),
            Example(input: "en-12", tag: "en-12", code: "en"),
            Example(input: "en-ÜS", tag: "en-üs", code: "en"),
            // The script comes before the region.
            Example(input: "en-US-Latn", tag: "en-US-latn", code: "en", region: "US"),
            // A singleton stops the parsing of the script and region.
            Example(input: "zh-x-Hant", tag: "zh-x-hant", code: "zh"),
            Example(input: "en-US-x-Twain", tag: "en-US-x-twain", code: "en", region: "US"),
            Example(input: "en-a-bbb-US", tag: "en-a-bbb-us", code: "en"),
            Example(input: "x-Klingon", tag: "x-klingon", code: "x"),
            // Empty subtags are ignored.
            Example(input: "", tag: "", code: ""),
            Example(input: "-", tag: "", code: ""),
            Example(input: "en--US", tag: "en-US", code: "en", region: "US"),
            // Invalid tags are kept lowercased.
            Example(input: "12-34", tag: "12-34", code: "12"),
        ])
        func parsesSubtags(_ example: Example) {
            let language = Language(example.input)
            #expect(language.tag == example.tag)
            #expect(language.code == example.code)
            #expect(language.script == example.script)
            #expect(language.region == example.region)
            // Parsing the canonical tag again gives the same tag.
            #expect(Language(example.tag).tag == example.tag)
        }
    }

    struct Subtags {
        @Test(arguments: [("en", "en"), ("EN", "en"), ("eN", "en"), ("", "")])
        func normalizesCode(input: String, expected: String) {
            let literal: Language.Code = Language.Code(stringLiteral: input)
            #expect(Language.Code(input).rawValue == expected)
            #expect(literal.rawValue == expected)
            #expect(Language.Code(input).description == expected)
        }

        @Test(arguments: [("Hant", "Hant"), ("hANT", "Hant"), ("HANT", "Hant"), ("hant", "Hant"), ("", "")])
        func normalizesScript(input: String, expected: String) {
            let literal: Language.Script = Language.Script(stringLiteral: input)
            #expect(Language.Script(input).rawValue == expected)
            #expect(literal.rawValue == expected)
            #expect(Language.Script(input).description == expected)
        }

        @Test(arguments: [("GB", "GB"), ("gb", "GB"), ("Gb", "GB"), ("419", "419"), ("", "")])
        func normalizesRegion(input: String, expected: String) {
            let literal: Language.Region = Language.Region(stringLiteral: input)
            #expect(Language.Region(input).rawValue == expected)
            #expect(literal.rawValue == expected)
            #expect(Language.Region(input).description == expected)
        }

        private let en = Locale(identifier: "en")

        @Test(arguments: [("fr", "French"), ("", nil)] as [(String, String?)])
        func localizesCode(input: String, expected: String?) {
            #expect(Language.Code(input).localizedName(in: en) == expected)
        }

        @Test(arguments: [("Hant", "Traditional Han"), ("", nil)] as [(String, String?)])
        func localizesScript(input: String, expected: String?) {
            #expect(Language.Script(input).localizedName(in: en) == expected)
        }

        @Test(arguments: [("CA", "Canada"), ("419", "Latin America"), ("", nil)] as [(String, String?)])
        func localizesRegion(input: String, expected: String?) {
            #expect(Language.Region(input).localizedName(in: en) == expected)
        }

        @Test func hashesByNormalizedValue() {
            #expect(Set([Language.Region("gb"), "GB"]).count == 1)
            let names: [Language.Code: String] = ["en": "English"]
            #expect(names["EN"] == "English")
        }
    }

    struct Equality {
        @Test(arguments: ["en-US", "en-us", "EN-US", "en_US"] as [Language])
        func ignoresCaseAndSeparator(_ language: Language) {
            #expect(language == "en-US")
            #expect(language.hashValue == ("en-US" as Language).hashValue)
        }

        @Test func matchesDictionaryKeys() {
            let voices: [Language: String] = ["en-US": "Samantha"]
            #expect(voices["en_us"] == "Samantha")
        }

        @Test func distinguishesSubtags() {
            #expect(("en-US" as Language) != "en-GB")
            #expect(("en-US" as Language) != "en")
            #expect(("zh-Hant" as Language) != "zh")
            #expect(("zh-Hant-TW" as Language) != "zh-TW")
        }
    }

    struct PrimaryLanguage {
        @Test(arguments: [
            Conversion(input: "en", expected: "en"),
            Conversion(input: "en-US", expected: "en"),
            Conversion(input: "zh-Hant-TW", expected: "zh"),
            Conversion(input: "en_US_POSIX", expected: "en"),
            Conversion(input: "zh-yue-HK", expected: "zh"),
            Conversion(input: "en-x-twain", expected: "en"),
        ])
        func keepsOnlyThePrimarySubtag(_ example: Conversion) {
            #expect(Language(example.input).primaryLanguage.tag == example.expected)
        }
    }

    struct Locales {
        @Test(arguments: [
            Conversion(input: "en_US", expected: "en-US"),
            Conversion(input: "uz_Cyrl_UZ", expected: "uz-Cyrl-UZ"),
            Conversion(input: "zh_TW@calendar=roc", expected: "zh-TW"),
            Conversion(input: "en_US@rg=frzzzz;calendar=gregorian", expected: "en-US"),
        ])
        func initWithLocaleIgnoresKeywords(_ example: Conversion) {
            #expect(Language(locale: Locale(identifier: example.input)).tag == example.expected)
        }

        @Test func localeUsesTheTag() {
            #expect(Language("zh_hant_tw").locale.identifier == "zh-Hant-TW")
        }
    }

    struct Description {
        @Test func isTheTag() {
            #expect(Language("en_us").description == "en-US")
        }

        @Test func localized() {
            let english = Locale(identifier: "en")
            let language = Language("fr-CA")
            #expect(language.localizedDescription(in: english) == "French (Canada)")
            #expect(language.localizedLanguage(in: english) == "French")
            #expect(Language("").localizedLanguage(in: english) == nil)
            #expect(Language("zzzz").localizedLanguage(in: english) == nil)
        }

        @Test(arguments: [
            ("fr-CA", "Canada"),
            ("es-419", "Latin America"),
            ("fr", nil),
            ("", nil),
        ] as [(String, String?)])
        func localizedRegion(tag: String, expected: String?) {
            #expect(Language(tag).localizedRegion(in: Locale(identifier: "en")) == expected)
        }
    }

    struct Serialization {
        @Test func stringLiteral() {
            let language: Language = "zh_hant_TW"
            #expect(language.tag == "zh-Hant-TW")
        }

        @Test func json() throws {
            let language = try #require(try Language(json: "en_us", warnings: nil))
            #expect(language.tag == "en-US")
            #expect(language.jsonValue == .string("en-US"))
            #expect(try Language(json: language.jsonValue, warnings: nil) == language)
            #expect(try Language(json: nil as String?, warnings: nil) == nil)
            #expect(try Language(json: 42, warnings: nil) == nil)
        }

        @Test func codable() throws {
            let data = try JSONEncoder().encode(["en_us" as Language])
            #expect(String(data: data, encoding: .utf8) == #"["en-US"]"#)
            #expect(try JSONDecoder().decode([Language].self, from: data) == ["en-US"])
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode([Language].self, from: Data("[42]".utf8))
            }
        }
    }
}
