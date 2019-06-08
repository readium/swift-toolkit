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
    
    func testParseOrientationFromEPUB() {
        XCTAssertEqual(EPUBRendition.Orientation(epub: "auto"), .auto)
        XCTAssertEqual(EPUBRendition.Orientation(epub: "landscape"), .landscape)
        XCTAssertEqual(EPUBRendition.Orientation(epub: "portrait"), .portrait)
        XCTAssertEqual(EPUBRendition.Orientation(epub: "unknown"), .auto)
        XCTAssertEqual(EPUBRendition.Orientation(epub: "unknown", fallback: .portrait), .portrait)
    }
    
    func testParseLayout() {
        XCTAssertEqual(EPUBRendition.Layout(rawValue: "fixed"), .fixed)
        XCTAssertEqual(EPUBRendition.Layout(rawValue: "reflowable"), .reflowable)
    }
    
    func testParseLayoutFromEPUB() {
        XCTAssertEqual(EPUBRendition.Layout(epub: "reflowable"), .reflowable)
        XCTAssertEqual(EPUBRendition.Layout(epub: "pre-paginated"), .fixed)
        XCTAssertEqual(EPUBRendition.Layout(epub: "unknown"), .reflowable)
        XCTAssertEqual(EPUBRendition.Layout(epub: "unknown", fallback: .fixed), .fixed)
    }
    
    func testParseOverflow() {
        XCTAssertEqual(EPUBRendition.Overflow(rawValue: "auto"), .auto)
        XCTAssertEqual(EPUBRendition.Overflow(rawValue: "paginated"), .paginated)
        XCTAssertEqual(EPUBRendition.Overflow(rawValue: "scrolled"), .scrolled)
        XCTAssertEqual(EPUBRendition.Overflow(rawValue: "scrolled-continuous"), .scrolledContinuous)
    }
    
    func testParseOverflowFromEPUB() {
        XCTAssertEqual(EPUBRendition.Overflow(epub: "auto"), .auto)
        XCTAssertEqual(EPUBRendition.Overflow(epub: "paginated"), .paginated)
        XCTAssertEqual(EPUBRendition.Overflow(epub: "scrolled-doc"), .scrolled)
        XCTAssertEqual(EPUBRendition.Overflow(epub: "scrolled-continuous"), .scrolledContinuous)
        XCTAssertEqual(EPUBRendition.Overflow(epub: "unknown"), .auto)
        XCTAssertEqual(EPUBRendition.Overflow(epub: "unknown", fallback: .paginated), .paginated)
    }
    
    func testParseSpread() {
        XCTAssertEqual(EPUBRendition.Spread(rawValue: "auto"), .auto)
        XCTAssertEqual(EPUBRendition.Spread(rawValue: "both"), .both)
        XCTAssertEqual(EPUBRendition.Spread(rawValue: "none"), EPUBRendition.Spread.none)  // For some reason this fails if we don't fully qualify .none
        XCTAssertEqual(EPUBRendition.Spread(rawValue: "landscape"), .landscape)
    }
    
    func testParseSpreadFromEPUB() {
        XCTAssertEqual(EPUBRendition.Spread(epub: "auto"), .auto)
        XCTAssertEqual(EPUBRendition.Spread(epub: "both"), .both)
        XCTAssertEqual(EPUBRendition.Spread(epub: "none"), EPUBRendition.Spread.none)  // For some reason this fails if we don't fully qualify .none
        XCTAssertEqual(EPUBRendition.Spread(epub: "landscape"), .landscape)
        XCTAssertEqual(EPUBRendition.Spread(epub: "portrait"), .both)  // `portait` is deprecated and equivalent to `both`
        XCTAssertEqual(EPUBRendition.Spread(epub: "unknown"), .auto)
        XCTAssertEqual(EPUBRendition.Spread(epub: "unknown", fallback: .landscape), .landscape)
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
