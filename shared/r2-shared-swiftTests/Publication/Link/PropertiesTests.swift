//
//  PropertiesTests.swift
//  r2-shared-swiftTests
//
//  Created by Mickaël Menu on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class PropertiesTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Properties(json: [:]),
            Properties()
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? Properties(json: [
                "orientation": "auto",
                "page": "left",
                "contains": ["mathml", "onix"],
                "layout": "fixed",
                "media-overlay": "http://uri",
                "overflow": "scrolled-continuous",
                "spread": "landscape",
                "encrypted": [
                    "algorithm": "http://algo"
                ],
                "numberOfItems": 42,
                "price": [
                    "currency": "EUR",
                    "value": 3.65
                ],
                "indirectAcquisition": [
                    [ "type": "acqtype" ]
                ]
            ]),
            Properties(
                orientation: .auto,
                page: .left,
                contains: ["mathml", "onix"],
                layout: .fixed,
                mediaOverlay: "http://uri",
                overflow: .scrolledContinuous,
                spread: .landscape,
                encryption: Encryption(algorithm: "http://algo"),
                numberOfItems: 42,
                price: OPDSPrice(currency: "EUR", value: 3.65),
                indirectAcquisition: [OPDSAcquisition(type: "acqtype")]
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Properties(json: ""))
    }
    
    func testParseJSONAllowsNil() {
        XCTAssertNil(try Properties(json: nil))
    }
    
    func testParseJSONOtherProperties() {
        XCTAssertEqual(
            try? Properties(json: [
                "orientation": "auto",
                "other-property1": "value",
                "other-property2": [42],
            ]),
            Properties(
                orientation: .auto,
                otherProperties: [
                    "other-property1": "value",
                    "other-property2": [42]
                ]
            )
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(Properties().json, [:])
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            Properties(
                orientation: .landscape,
                page: .right,
                contains: ["mathml", "onix"],
                layout: .fixed,
                mediaOverlay: "http://uri",
                overflow: .scrolledContinuous,
                spread: .landscape,
                encryption: Encryption(algorithm: "http://algo"),
                numberOfItems: 42,
                price: OPDSPrice(currency: "EUR", value: 3.65),
                indirectAcquisition: [OPDSAcquisition(type: "acqtype")],
                otherProperties: [
                    "other-property1": "value",
                ]
            ).json as Any,
            [
                "orientation": "landscape",
                "page": "right",
                "contains": ["mathml", "onix"],
                "layout": "fixed",
                "media-overlay": "http://uri",
                "overflow": "scrolled-continuous",
                "spread": "landscape",
                "encrypted": [
                    "algorithm": "http://algo"
                ],
                "numberOfItems": 42,
                "price": [
                    "currency": "EUR",
                    "value": 3.65
                ],
                "indirectAcquisition": [
                    [ "type": "acqtype" ]
                ],
                "other-property1": "value"
            ]
        )
    }
    
}
