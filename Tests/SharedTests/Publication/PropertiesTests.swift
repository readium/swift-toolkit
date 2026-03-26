//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class PropertiesTests: XCTestCase {
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Properties(json: [:] as JSONValue),
            Properties()
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            try? Properties(json: [
                "other-property1": "value",
                "other-property2": [42],
            ] as JSONValue),
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
        XCTAssertNil(try Properties(json: nil as JSONValue?))
    }

    func testGetMinimalJSON() {
        XCTAssertEqual(Properties().jsonObject, [:] as [String: JSONValue])
    }

    func testGetFullJSON() {
        XCTAssertEqual(
            Properties([
                "other-property1": "value",
                "other-property2": [42],
            ]).jsonObject as [String: JSONValue],
            [
                "other-property1": "value",
                "other-property2": [42],
            ] as [String: JSONValue]
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

        XCTAssertEqual(
            properties.jsonObject as [String: JSONValue],
            [
                "other-property1": "override",
                "other-property2": [42],
                "additional": "property",
            ] as [String: JSONValue]
        )
    }

    func testGetPageWhenMissing() {
        XCTAssertNil(Properties().page)
    }

    func testGetPageWhenAvailable() {
        XCTAssertEqual(Properties(["page": "center"]).page, .center)
    }
}
