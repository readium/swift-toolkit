//
//  WPRenditionTests.swift
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

class WPRenditionTests: XCTestCase {
    
    func testParseOrientation() {
        XCTAssertEqual(WPOrientation(rawValue: "auto"), .auto)
        XCTAssertEqual(WPOrientation(rawValue: "landscape"), .landscape)
        XCTAssertEqual(WPOrientation(rawValue: "portrait"), .portrait)
    }
    
    func testParsePage() {
        XCTAssertEqual(WPPage(rawValue: "left"), .left)
        XCTAssertEqual(WPPage(rawValue: "right"), .right)
        XCTAssertEqual(WPPage(rawValue: "center"), .center)
    }
    
    func testParseLayout() {
        XCTAssertEqual(WPLayout(rawValue: "fixed"), .fixed)
        XCTAssertEqual(WPLayout(rawValue: "reflowable"), .reflowable)
    }
    
    func testParseOverflow() {
        XCTAssertEqual(WPOverflow(rawValue: "auto"), .auto)
        XCTAssertEqual(WPOverflow(rawValue: "paginated"), .paginated)
        XCTAssertEqual(WPOverflow(rawValue: "scrolled"), .scrolled)
        XCTAssertEqual(WPOverflow(rawValue: "scrolled-continuous"), .scrolledContinuous)
    }
    
    func testParseSpread() {
        XCTAssertEqual(WPSpread(rawValue: "auto"), .auto)
        XCTAssertEqual(WPSpread(rawValue: "both"), .both)
        XCTAssertEqual(WPSpread(rawValue: "none"), WPSpread.none)  // For some reason this fails if we don't fully qualify .none
        XCTAssertEqual(WPSpread(rawValue: "landscape"), .landscape)
    }
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? WPRendition(json: [:]),
            WPRendition()
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? WPRendition(json: [
                "layout": "reflowable",
                "orientation": "portrait",
                "overflow": "paginated",
                "spread": "both"
            ]),
            WPRendition(
                layout: .reflowable,
                orientation: .portrait,
                overflow: .paginated,
                spread: .both
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try WPRendition(json: ""))
    }
    
    func testParseAllowsNil() {
        XCTAssertNil(try WPRendition(json: nil))
    }
    
    func testGetMinimalJSON() {
        XCTAssertNil(WPRendition().json)
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            WPRendition(
                layout: .reflowable,
                orientation: .portrait,
                overflow: .paginated,
                spread: .both
            ).json as Any,
            [
                "layout": "reflowable",
                "orientation": "portrait",
                "overflow": "paginated",
                "spread": "both"
            ]
        )
    }

}
