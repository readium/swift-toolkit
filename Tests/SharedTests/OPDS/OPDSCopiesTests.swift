//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class OPDSCopiesTests: XCTestCase {
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? OPDSCopies(json: [:] as [String: Any]),
            OPDSCopies(total: nil, available: nil)
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            try? OPDSCopies(json: [
                "total": 5,
                "available": 6,
            ]),
            OPDSCopies(total: 5, available: 6)
        )
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try OPDSCopies(json: ""))
    }

    func testParseRequiresPositiveTotal() {
        XCTAssertEqual(
            try? OPDSCopies(json: [
                "total": -5,
                "available": 6,
            ]),
            OPDSCopies(total: nil, available: 6)
        )
    }

    func testParseRequiresPositivePosition() {
        XCTAssertEqual(
            try? OPDSCopies(json: [
                "total": 5,
                "available": -6,
            ]),
            OPDSCopies(total: 5, available: nil)
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            OPDSCopies(total: nil, available: nil).json,
            [:] as [String: Any]
        )
    }

    func testGetFullJSON() {
        AssertJSONEqual(
            OPDSCopies(total: 5, available: 6).json,
            [
                "total": 5,
                "available": 6,
            ]
        )
    }
}
