//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class LocalizedStringTests: XCTestCase {
    func testParseJSONString() {
        XCTAssertEqual(
            try? LocalizedString(json: "a string"),
            .nonlocalized("a string")
        )
    }

    func testParseJSONLocalizedStrings() {
        XCTAssertEqual(
            try? LocalizedString(json: ["en": "a string", "fr": "une chaîne"]),
            .localized(["en": "a string", "fr": "une chaîne"])
        )
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try LocalizedString(json: ["a string", "une chaîne"]))
    }

    func testParseAllowsNil() {
        XCTAssertNil(try LocalizedString(json: nil))
    }

    func testGetJSON() {
        AssertJSONEqual(
            LocalizedString.nonlocalized("a string").json,
            "a string"
        )
        AssertJSONEqual(
            LocalizedString.localized(["en": "a string", "fr": "une chaîne"]).json,
            ["en": "a string", "fr": "une chaîne"]
        )
    }

    func testGetString() {
        XCTAssertEqual(
            LocalizedString.localized(["en": "hello", "fr": "bonjour"]).string,
            "hello"
        )
    }

    func testStringConversion() {
        XCTAssertEqual(
            String(describing: LocalizedString.localized(["en": "hello", "fr": "bonjour"])),
            "hello"
        )
    }

    func testGetStringByLanguageCode() {
        XCTAssertEqual(
            LocalizedString.localized(["en": "hello", "fr": "bonjour"]).string(forLanguageCode: "fr"),
            "bonjour"
        )
    }

    func testConvertFromLocalizedString() {
        let string = LocalizedString.localized(["en": "hello"]).localizedString
        XCTAssertEqual(string, .localized(["en": "hello"]))
    }

    func testConvertFromStringLiteral() {
        let string: LocalizedString = "hello".localizedString
        XCTAssertEqual(string, .nonlocalized("hello"))
    }

    func testConvertFromDictionaryLiteral() {
        let strings: LocalizedString = ["en": "hello", "fr": "bonjour"].localizedString
        XCTAssertEqual(strings, .localized(["en": "hello", "fr": "bonjour"]))
    }
}
