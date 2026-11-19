//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class AltIdentifierTests: XCTestCase {
    func testParseJSONString() {
        XCTAssertEqual(
            try? AltIdentifier(json: "urn:isbn:9781449325862"),
            AltIdentifier(value: "urn:isbn:9781449325862")
        )
    }

    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? AltIdentifier(json: ["value": "9781449325862"]),
            AltIdentifier(value: "9781449325862")
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            try? AltIdentifier(json: [
                "value": "9781449325862",
                "scheme": "urn:isbn",
            ] as JSONValue),
            AltIdentifier(value: "9781449325862", scheme: "urn:isbn")
        )
    }

    func testParseJSONRequiresValue() {
        XCTAssertThrowsError(try AltIdentifier(json: [
            "scheme": "urn:isbn",
        ]))
    }

    /// Without a scheme, the value collapses to a bare string.
    func testGetMinimalJSON() {
        XCTAssertEqual(
            AltIdentifier(value: "urn:isbn:9781449325862").jsonValue,
            .string("urn:isbn:9781449325862")
        )
    }

    func testGetFullJSON() {
        XCTAssertEqual(
            AltIdentifier(value: "9781449325862", scheme: "urn:isbn").jsonValue,
            [
                "value": "9781449325862",
                "scheme": "urn:isbn",
            ] as JSONValue
        )
    }
}
