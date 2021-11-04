//
//  PresentationTests.swift
//  r2-shared-swift
//
//  Created by Mickaël on 24/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class PresentationTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Presentation(json: [:]),
            Presentation()
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? Presentation(json: [
                "clipped": true,
                "continuous": false,
                "fit": "cover",
                "orientation": "landscape",
                "overflow": "paginated",
                "spread": "both",
                "layout": "fixed"
            ]),
            Presentation(
                clipped: true,
                continuous: false,
                fit: .cover,
                orientation: .landscape,
                overflow: .paginated,
                spread: .both,
                layout: .fixed
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Presentation(json: ""))
    }
    
    func testParseAllowsNil() {
        XCTAssertEqual(try Presentation(json: nil), Presentation())
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(Presentation().json, [:])
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            Presentation(
                clipped: true,
                continuous: false,
                fit: .cover,
                orientation: .landscape,
                overflow: .paginated,
                spread: .both,
                layout: .fixed
            ).json as Any,
            [
                "clipped": true,
                "continuous": false,
                "fit": "cover",
                "orientation": "landscape",
                "overflow": "paginated",
                "spread": "both",
                "layout": "fixed"
            ]
        )
    }

    func testParseFitFromJSONValue() {
        XCTAssertEqual(Presentation.Fit(rawValue: "contain"), .contain)
        XCTAssertEqual(Presentation.Fit(rawValue: "cover"), .cover)
        XCTAssertEqual(Presentation.Fit(rawValue: "width"), .width)
        XCTAssertEqual(Presentation.Fit(rawValue: "height"), .height)
        XCTAssertNil(Presentation.Fit(rawValue: "foobar"))
    }
    
    func testGetFitJSONValue() {
        XCTAssertEqual("contain", Presentation.Fit.contain.rawValue)
        XCTAssertEqual("cover", Presentation.Fit.cover.rawValue)
        XCTAssertEqual("width", Presentation.Fit.width.rawValue)
        XCTAssertEqual("height", Presentation.Fit.height.rawValue)
    }
    
    func testParseOrientationFromJSONValue() {
        XCTAssertEqual(Presentation.Orientation(rawValue: "landscape"), .landscape)
        XCTAssertEqual(Presentation.Orientation(rawValue: "portrait"), .portrait)
        XCTAssertEqual(Presentation.Orientation(rawValue: "auto"), .auto)
        XCTAssertNil(Presentation.Orientation(rawValue: "foobar"))
    }
    
    func testGetOrientationJSONValue() {
        XCTAssertEqual("landscape", Presentation.Orientation.landscape.rawValue)
        XCTAssertEqual("portrait", Presentation.Orientation.portrait.rawValue)
        XCTAssertEqual("auto", Presentation.Orientation.auto.rawValue)
    }

    func testParseOverflowFromJSONValue() {
        XCTAssertEqual(Presentation.Overflow(rawValue: "paginated"), .paginated)
        XCTAssertEqual(Presentation.Overflow(rawValue: "scrolled"), .scrolled)
        XCTAssertEqual(Presentation.Overflow(rawValue: "auto"), .auto)
        XCTAssertNil(Presentation.Overflow(rawValue: "foobar"))
    }
    
    func testGetOverflowJSONValue() {
        XCTAssertEqual("paginated", Presentation.Overflow.paginated.rawValue)
        XCTAssertEqual("scrolled", Presentation.Overflow.scrolled.rawValue)
        XCTAssertEqual("auto", Presentation.Overflow.auto.rawValue)
    }

    func testParsePageFromJSONValue() {
        XCTAssertEqual(Presentation.Page(rawValue: "left"), .left)
        XCTAssertEqual(Presentation.Page(rawValue: "right"), .right)
        XCTAssertEqual(Presentation.Page(rawValue: "center"), .center)
        XCTAssertNil(Presentation.Page(rawValue: "foobar"))
    }
    
    func testGetPageJSONValue() {
        XCTAssertEqual("left", Presentation.Page.left.rawValue)
        XCTAssertEqual("right", Presentation.Page.right.rawValue)
        XCTAssertEqual("center", Presentation.Page.center.rawValue)
    }
    
    func testParseSpreadFromJSONValue() {
        XCTAssertEqual(Presentation.Spread(rawValue: "landscape"), .landscape)
        XCTAssertEqual(Presentation.Spread(rawValue: "both"), .both)
        XCTAssertEqual(Presentation.Spread(rawValue: "none"), Presentation.Spread.none)  // For some reason this fails if we don't fully qualify .none
        XCTAssertEqual(Presentation.Spread(rawValue: "auto"), .auto)
        XCTAssertNil(Presentation.Spread(rawValue: "foobar"))
    }
    
    func testGetSpreadJSONValue() {
        XCTAssertEqual("landscape", Presentation.Spread.landscape.rawValue)
        XCTAssertEqual("both", Presentation.Spread.both.rawValue)
        XCTAssertEqual("none", Presentation.Spread.none.rawValue)
        XCTAssertEqual("auto", Presentation.Spread.auto.rawValue)
    }

}
