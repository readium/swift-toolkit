//
//  LocalizedStringTests.swift
//  r2-shared-swiftTests
//
//  Created by Mickaël Menu on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

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
        let string: LocalizedString = LocalizedString.localized(["en": "hello"]).localizedString
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
