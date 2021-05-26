//
//  OPDSPriceTests.swift
//  r2-shared-swiftTests
//
//  Created by Mickaël Menu on 12.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class OPDSPriceTests: XCTestCase {
    
    func testParseJSON() {
        XCTAssertEqual(
            try? OPDSPrice(json: [
                "currency": "EUR",
                "value": 4.65
            ]),
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
            "value": 4.65
        ]))
    }
    
    func testParseJSONRequiresValue() {
        XCTAssertThrowsError(try OPDSPrice(json: [
            "currency": "EUR"
        ]))
    }
    
    func testParseJSONRequiresPositiveValue() {
        XCTAssertThrowsError(try OPDSPrice(json: [
            "currency": "EUR",
            "value": -20
        ]))
    }
    
    func testGetJSON() {
        AssertJSONEqual(
            OPDSPrice(currency: "EUR", value: 4.65).json,
            [
                "currency": "EUR",
                "value": 4.65
            ]
        )
    }

}
