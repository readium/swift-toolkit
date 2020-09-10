//
//  OPDSHoldsTests.swift
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

class OPDSHoldsTests: XCTestCase {

    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? OPDSHolds(json: [:]),
            OPDSHolds(total: nil, position: nil)
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? OPDSHolds(json: [
                "total": 5,
                "position": 6
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
                "position": 6
            ]),
            OPDSHolds(total: nil, position: 6)
        )
    }
    
    func testParseRequiresPositivePosition() {
        XCTAssertEqual(
            try? OPDSHolds(json: [
                "total": 5,
                "position": -6
            ]),
            OPDSHolds(total: 5, position: nil)
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            OPDSHolds(total: nil, position: nil).json,
            [:]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            OPDSHolds(total: 5, position: 6).json,
            [
                "total": 5,
                "position": 6
            ]
        )
    }

}
