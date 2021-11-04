//
//  OPDSAvailabilityTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 24/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class OPDSAvailabilityTests: XCTestCase {

    func testParseStateFromJSON() {
        XCTAssertEqual(OPDSAvailability.State(rawValue: "available"), .available)
        XCTAssertEqual(OPDSAvailability.State(rawValue: "unavailable"), .unavailable)
        XCTAssertEqual(OPDSAvailability.State(rawValue: "reserved"), .reserved)
        XCTAssertEqual(OPDSAvailability.State(rawValue: "ready"), .ready)
        XCTAssertNil(OPDSAvailability.State(rawValue: "foobar"))
    }

    func testGetStateAsJSON() {
        XCTAssertEqual(OPDSAvailability.State.available.rawValue, "available")
        XCTAssertEqual(OPDSAvailability.State.unavailable.rawValue, "unavailable")
        XCTAssertEqual(OPDSAvailability.State.reserved.rawValue, "reserved")
        XCTAssertEqual(OPDSAvailability.State.ready.rawValue, "ready")
    }
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? OPDSAvailability(json: ["state": "available"]),
            OPDSAvailability(state: .available)
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? OPDSAvailability(json: [
                "state": "available",
                "since": "2001-01-01T12:36:27+0000",
                "until": "2001-02-01T12:36:27+0000"
            ]),
            OPDSAvailability(
                state: .available,
                since: "2001-01-01T12:36:27+0000".dateFromISO8601,
                until: "2001-02-01T12:36:27+0000".dateFromISO8601
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try OPDSAvailability(json: [:]))
    }
    
    func testParseRequiresState() {
        XCTAssertNil(try? OPDSAvailability(json: ["since": "2001-01-01T12:36:27+0000"]))
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            OPDSAvailability(state: .available).json,
            ["state": "available"]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            OPDSAvailability(
                state: .available,
                since: "2001-01-01T12:36:27+0000".dateFromISO8601,
                until: "2001-02-01T12:36:27+0000".dateFromISO8601
            ).json,
            [
                "state": "available",
                "since": "2001-01-01T12:36:27+0000",
                "until": "2001-02-01T12:36:27+0000"
            ]
        )
    }
    
}
