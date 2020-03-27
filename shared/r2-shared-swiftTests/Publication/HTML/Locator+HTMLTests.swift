//
//  Locator+HTMLTests.swift
//  r2-shared-swift
//
//  Created by Mickaël on 25/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class LocatorLocationsHTMLTests: XCTestCase {

    func testNoCSSSelector() {
        XCTAssertNil(Locator.Locations().cssSelector)
    }
    
    func testCSSSelector() {
        XCTAssertEqual(Locator.Locations(otherLocations: ["cssSelector": "p"]).cssSelector, "p")
    }

    func testNoPartialCFI() {
        XCTAssertNil(Locator.Locations().partialCFI)
    }
    
    func testPartialCFI() {
        XCTAssertEqual(Locator.Locations(otherLocations: ["partialCfi": "epubcfi(/4)"]).partialCFI, "epubcfi(/4)")
    }

    func testNoDOMRange() {
        XCTAssertNil(Locator.Locations().domRange)
    }
    
    func testDOMRange() {
        XCTAssertEqual(
            Locator.Locations(otherLocations: [
                "domRange": [
                    "start": [
                        "cssSelector": "p",
                        "textNodeIndex": 4
                    ]
                ]
            ]).domRange,
            DOMRange(start: .init(cssSelector: "p", textNodeIndex: 4))
        )
    }

}
