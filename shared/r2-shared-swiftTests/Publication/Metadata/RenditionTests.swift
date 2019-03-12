//
//  RenditionTests.swift
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

class RenditionTests: XCTestCase {
    
    func testParseOrientation() {
        XCTAssertEqual(RenditionOrientation(rawValue: "auto"), .auto)
        XCTAssertEqual(RenditionOrientation(rawValue: "landscape"), .landscape)
        XCTAssertEqual(RenditionOrientation(rawValue: "portrait"), .portrait)
    }
    
    func testParsePage() {
        XCTAssertEqual(RenditionPage(rawValue: "left"), .left)
        XCTAssertEqual(RenditionPage(rawValue: "right"), .right)
        XCTAssertEqual(RenditionPage(rawValue: "center"), .center)
    }

    func testParseLayout() {
        XCTAssertEqual(RenditionLayout(rawValue: "fixed"), .fixed)
        XCTAssertEqual(RenditionLayout(rawValue: "reflowable"), .reflowable)
    }
    
    func testParseOverflow() {
        XCTAssertEqual(RenditionOverflow(rawValue: "auto"), .auto)
        XCTAssertEqual(RenditionOverflow(rawValue: "paginated"), .paginated)
        XCTAssertEqual(RenditionOverflow(rawValue: "scrolled"), .scrolled)
        XCTAssertEqual(RenditionOverflow(rawValue: "scrolled-continuous"), .scrolledContinuous)
    }
    
    func testParseSpread() {
        XCTAssertEqual(RenditionSpread(rawValue: "auto"), .auto)
        XCTAssertEqual(RenditionSpread(rawValue: "both"), .both)
        XCTAssertEqual(RenditionSpread(rawValue: "none"), RenditionSpread.none)  // For some reason this fails if we don't fully qualify .none
        XCTAssertEqual(RenditionSpread(rawValue: "landscape"), .landscape)
    }
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Rendition(json: [:]),
            Rendition()
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? Rendition(json: [
                "layout": "reflowable",
                "orientation": "portrait",
                "overflow": "paginated",
                "spread": "both"
            ]),
            Rendition(
                layout: .reflowable,
                orientation: .portrait,
                overflow: .paginated,
                spread: .both
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Rendition(json: ""))
    }
    
    func testParseAllowsNil() {
        XCTAssertNil(try Rendition(json: nil))
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(Rendition().json, [:])
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            Rendition(
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
