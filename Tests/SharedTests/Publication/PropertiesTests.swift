//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class PropertiesTests: XCTestCase {
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Properties(json: [:] as [String: Any]),
            Properties()
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            try? Properties(json: [
                "other-property1": "value",
                "other-property2": [42],
            ] as [String: Any]),
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
        AssertJSONEqual(Properties().json, [:] as [String: Any])
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
            ] as [String: Any]
        )
    }

    func testAddProperties() {
        var properties = Properties([
            "other-property1": "value",
            "other-property2": [42],
        ])
        properties.add([
            "additional": "property",
            "other-property1": "override",
        ])

        AssertJSONEqual(
            properties.json as Any,
            [
                "other-property1": "override",
                "other-property2": [42],
                "additional": "property",
            ] as [String: Any]
        )
    }

    func testGetPageWhenMissing() {
        XCTAssertNil(Properties().page)
    }

    func testGetPageWhenAvailable() {
        XCTAssertEqual(Properties(["page": "center"]).page, .center)
    }
}
