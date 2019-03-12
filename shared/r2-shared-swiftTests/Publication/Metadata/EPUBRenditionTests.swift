//
//  EPUBRenditionTests.swift
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

class EPUBRenditionTests: XCTestCase {
    
    func testParseOrientation() {
        XCTAssertEqual(EPUBRendition.Orientation(rawValue: "auto"), .auto)
        XCTAssertEqual(EPUBRendition.Orientation(rawValue: "landscape"), .landscape)
        XCTAssertEqual(EPUBRendition.Orientation(rawValue: "portrait"), .portrait)
    }
    
    func testParseLayout() {
        XCTAssertEqual(EPUBRendition.Layout(rawValue: "fixed"), .fixed)
        XCTAssertEqual(EPUBRendition.Layout(rawValue: "reflowable"), .reflowable)
    }
    
    func testParseOverflow() {
        XCTAssertEqual(EPUBRendition.Overflow(rawValue: "auto"), .auto)
        XCTAssertEqual(EPUBRendition.Overflow(rawValue: "paginated"), .paginated)
        XCTAssertEqual(EPUBRendition.Overflow(rawValue: "scrolled"), .scrolled)
        XCTAssertEqual(EPUBRendition.Overflow(rawValue: "scrolled-continuous"), .scrolledContinuous)
    }
    
    func testParseSpread() {
        XCTAssertEqual(EPUBRendition.Spread(rawValue: "auto"), .auto)
        XCTAssertEqual(EPUBRendition.Spread(rawValue: "both"), .both)
        XCTAssertEqual(EPUBRendition.Spread(rawValue: "none"), EPUBRendition.Spread.none)  // For some reason this fails if we don't fully qualify .none
        XCTAssertEqual(EPUBRendition.Spread(rawValue: "landscape"), .landscape)
    }
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? EPUBRendition(json: [:]),
            EPUBRendition()
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? EPUBRendition(json: [
                "layout": "reflowable",
                "orientation": "portrait",
                "overflow": "paginated",
                "spread": "both"
            ]),
            EPUBRendition(
                layout: .reflowable,
                orientation: .portrait,
                overflow: .paginated,
                spread: .both
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try EPUBRendition(json: ""))
    }
    
    func testParseAllowsNil() {
        XCTAssertNil(try EPUBRendition(json: nil))
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(EPUBRendition().json, [:])
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            EPUBRendition(
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
