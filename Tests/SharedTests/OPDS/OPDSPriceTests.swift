//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class OPDSPriceTests: XCTestCase {
    func testParseJSON() {
        XCTAssertEqual(
            try? OPDSPrice(json: [
                "currency": "EUR",
                "value": 4.65,
            ] as [String: Any]),
            OPDSPrice(currency: "EUR", value: 4.65)
        )
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try OPDSPrice(json: ""))
    }

    func testParseJSONNil() {
        XCTAssertNil(try OPDSPrice(json: nil))
    }

    func testParseJSONRequiresCurrency() {
        XCTAssertThrowsError(try OPDSPrice(json: [
            "value": 4.65,
        ]))
    }

    func testParseJSONRequiresValue() {
        XCTAssertThrowsError(try OPDSPrice(json: [
            "currency": "EUR",
        ]))
    }

    func testParseJSONRequiresPositiveValue() {
        XCTAssertThrowsError(try OPDSPrice(json: [
            "currency": "EUR",
            "value": -20,
        ] as [String: Any]))
    }

    func testGetJSON() {
        AssertJSONEqual(
            OPDSPrice(currency: "EUR", value: 4.65).json,
            [
                "currency": "EUR",
                "value": 4.65,
            ] as [String: Any]
        )
    }
}
