//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class OPDSHoldsTests: XCTestCase {
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? OPDSHolds(json: [:] as [String: Any]),
            OPDSHolds(total: nil, position: nil)
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            try? OPDSHolds(json: [
                "total": 5,
                "position": 6,
            ]),
            OPDSHolds(total: 5, position: 6)
        )
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try OPDSHolds(json: ""))
    }

    func testParseRequiresPositiveTotal() {
        XCTAssertEqual(
            try? OPDSHolds(json: [
                "total": -5,
                "position": 6,
            ]),
            OPDSHolds(total: nil, position: 6)
        )
    }

    func testParseRequiresPositivePosition() {
        XCTAssertEqual(
            try? OPDSHolds(json: [
                "total": 5,
                "position": -6,
            ]),
            OPDSHolds(total: 5, position: nil)
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            OPDSHolds(total: nil, position: nil).json,
            [:] as [String: Any]
        )
    }

    func testGetFullJSON() {
        AssertJSONEqual(
            OPDSHolds(total: 5, position: 6).json,
            [
                "total": 5,
                "position": 6,
            ]
        )
    }
}
