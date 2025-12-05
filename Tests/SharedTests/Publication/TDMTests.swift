//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class TDMTests: XCTestCase {
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? TDM(json: ["reservation": "none"]),
            TDM(reservation: .none)
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            try? TDM(json: [
                "reservation": "all",
                "policy": "https://policy",
            ] as [String: Any]),
            TDM(
                reservation: .all,
                policy: HTTPURL(string: "https://policy")
            )
        )
    }

    func testParseJSONRequiresReservation() {
        XCTAssertThrowsError(try TDM(json: [
            "policy": "https://policy",
        ]))
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            TDM(reservation: .none).json,
            ["reservation": "none"]
        )
    }

    func testGetFullJSON() {
        AssertJSONEqual(
            TDM(
                reservation: .all,
                policy: HTTPURL(string: "https://policy")
            ).json,
            [
                "reservation": "all",
                "policy": "https://policy",
            ] as [String: Any]
        )
    }
}
