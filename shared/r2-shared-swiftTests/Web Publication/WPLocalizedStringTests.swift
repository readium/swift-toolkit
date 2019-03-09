//
//  WPLocalizedStringTests.swift
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

class WPLocalizedStringTests: XCTestCase {

    func testParseJSONString() {
        XCTAssertEqual(
            try? WPLocalizedString(json: "a string"),
            .nonlocalized("a string")
        )
    }

    func testParseJSONLocalizedStrings() {
        XCTAssertEqual(
            try? WPLocalizedString(json: ["en": "a string", "fr": "une chaîne"]),
            .localized(["en": "a string", "fr": "une chaîne"])
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try WPLocalizedString(json: ["a string", "une chaîne"]))
    }
    
    func testParseAllowsNil() {
        XCTAssertNil(try WPLocalizedString(json: nil))
    }
    
    func testGetJSON() {
        AssertJSONEqual(
            WPLocalizedString.nonlocalized("a string").json,
            "a string"
        )
        AssertJSONEqual(
            WPLocalizedString.localized(["en": "a string", "fr": "une chaîne"]).json,
            ["en": "a string", "fr": "une chaîne"]
        )
    }
    
    func testGetString() {
        XCTAssertEqual(
            WPLocalizedString.localized(["en": "hello", "fr": "bonjour"]).string,
            "hello"
        )
    }
    
    func testStringConversion() {
        XCTAssertEqual(
            String(describing: WPLocalizedString.localized(["en": "hello", "fr": "bonjour"])),
            "hello"
        )
    }

    func testGetStringByLanguageCode() {
        XCTAssertEqual(
            WPLocalizedString.localized(["en": "hello", "fr": "bonjour"]).string(forLanguageCode: "fr"),
            "bonjour"
        )
    }
    
    func testMakeFromStringLiteral() {
        let string: WPLocalizedString = "hello"
        XCTAssertEqual(string, .nonlocalized("hello"))
    }
    
    func testMakeFromDictionaryLiteral() {
        let strings: WPLocalizedString = ["en": "hello", "fr": "bonjour"]
        XCTAssertEqual(strings, .localized(["en": "hello", "fr": "bonjour"]))
    }

}
