//
//  PropertiesTests.swift
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

class PropertiesTests: XCTestCase {
    
    func testParseOrientation() {
        XCTAssertEqual(Properties.Orientation(rawValue: "auto"), .auto)
        XCTAssertEqual(Properties.Orientation(rawValue: "landscape"), .landscape)
        XCTAssertEqual(Properties.Orientation(rawValue: "portrait"), .portrait)
    }
    
    func testParsePage() {
        XCTAssertEqual(Properties.Page(rawValue: "left"), .left)
        XCTAssertEqual(Properties.Page(rawValue: "right"), .right)
        XCTAssertEqual(Properties.Page(rawValue: "center"), .center)
    }
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Properties(json: [:]),
            Properties()
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? Properties(json: [
                "orientation": "auto",
                "page": "left",
                "other-property1": "value",
                "other-property2": [42],
            ]),
            Properties(
                orientation: .auto,
                page: .left,
                otherProperties: [
                    "other-property1": "value",
                    "other-property2": [42]
                ]
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Properties(json: ""))
    }
    
    func testParseJSONAllowsNil() {
        XCTAssertNil(try Properties(json: nil))
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(Properties().json, [:])
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            Properties(
                orientation: .landscape,
                page: .right,
                otherProperties: [
                    "other-property1": "value",
                    "other-property2": [42]
                ]
            ).json as Any,
            [
                "orientation": "landscape",
                "page": "right",
                "other-property1": "value",
                "other-property2": [42]
            ]
        )
    }
    
}
