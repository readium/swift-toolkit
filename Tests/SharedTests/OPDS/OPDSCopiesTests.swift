//
//  OPDSCopiesTests.swift
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

class OPDSCopiesTests: XCTestCase {

    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? OPDSCopies(json: [:]),
            OPDSCopies(total: nil, available: nil)
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? OPDSCopies(json: [
                "total": 5,
                "available": 6
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
                "available": 6
            ]),
            OPDSCopies(total: nil, available: 6)
        )
    }
    
    func testParseRequiresPositivePosition() {
        XCTAssertEqual(
            try? OPDSCopies(json: [
                "total": 5,
                "available": -6
            ]),
            OPDSCopies(total: 5, available: nil)
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            OPDSCopies(total: nil, available: nil).json,
            [:]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            OPDSCopies(total: 5, available: 6).json,
            [
                "total": 5,
                "available": 6
            ]
        )
    }

}
