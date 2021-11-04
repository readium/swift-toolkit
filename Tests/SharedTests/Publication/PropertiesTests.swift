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
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Properties(json: [:]),
            Properties()
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? Properties(json: [
                "other-property1": "value",
                "other-property2": [42],
            ]),
            Properties([
                "other-property1": "value",
                "other-property2": [42]
            ])
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
            Properties([
                "other-property1": "value",
                "other-property2": [42]
            ]).json as Any,
            [
                "other-property1": "value",
                "other-property2": [42]
            ]
        )
    }
    
    func testAddingProperties() {
        let properties = Properties([
            "other-property1": "value",
            "other-property2": [42]
        ])
        
        let copy = properties.adding([
            "additional": "property",
            "other-property1": "override"
        ])
        
        AssertJSONEqual(
            copy.json as Any,
            [
                "other-property1": "override",
                "other-property2": [42],
                "additional": "property"
            ]
        )
    }
    
}
