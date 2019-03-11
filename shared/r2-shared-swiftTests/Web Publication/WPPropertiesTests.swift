//
//  WPPropertiesTests.swift
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

class WPPropertiesTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? WPProperties(json: [:]),
            WPProperties()
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? WPProperties(json: [
                "orientation": "auto",
                "page": "left",
                "contains": ["mathml", "onix"],
                "layout": "fixed",
                "media-overlay": "http://uri",
                "overflow": "scrolled-continuous",
                "spread": "landscape",
                "encrypted": [
                    "algorithm": "http://algo"
                ]
            ]),
            WPProperties(
                orientation: .auto,
                page: .left,
                contains: ["mathml", "onix"],
                layout: .fixed,
                mediaOverlay: "http://uri",
                overflow: .scrolledContinuous,
                spread: .landscape,
                encrypted: WPEncrypted(algorithm: "http://algo")
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try WPProperties(json: ""))
    }
    
    func testParseJSONAllowsNil() {
        XCTAssertNil(try WPProperties(json: nil))
    }
    
    func testParseJSONOtherProperties() {
        XCTAssertEqual(
            try? WPProperties(json: [
                "orientation": "auto",
                "other-property1": "value",
                "other-property2": [42],
            ]),
            WPProperties(
                orientation: .auto,
                otherProperties: [
                    "other-property1": "value",
                    "other-property2": [42]
                ]
            )
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(WPProperties().json, [:])
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            WPProperties(
                orientation: .landscape,
                page: .right,
                contains: ["mathml", "onix"],
                layout: .fixed,
                mediaOverlay: "http://uri",
                overflow: .scrolledContinuous,
                spread: .landscape,
                encrypted: WPEncrypted(algorithm: "http://algo"),
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
                "other-property1": "value"
            ]
        )
    }
    
}
