//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

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
                        "textNodeIndex": 4,
                    ] as [String: Any],
                ],
            ]).domRange,
            DOMRange(start: .init(cssSelector: "p", textNodeIndex: 4))
        )
    }
}
