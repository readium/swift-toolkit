//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

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
                "other-property2": [42],
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
                "other-property2": [42],
            ]).json as Any,
            [
                "other-property1": "value",
                "other-property2": [42],
            ]
        )
    }

    func testAddingProperties() {
        let properties = Properties([
            "other-property1": "value",
            "other-property2": [42],
        ])

        let copy = properties.adding([
            "additional": "property",
            "other-property1": "override",
        ])

        AssertJSONEqual(
            copy.json as Any,
            [
                "other-property1": "override",
                "other-property2": [42],
                "additional": "property",
            ]
        )
    }
}
