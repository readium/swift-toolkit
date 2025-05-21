//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class LocatorLocationsAudioTests: XCTestCase {
    func testNoFragment() {
        XCTAssertNil(Locator.Locations().time)
    }

    func testMalformedFragment() {
        XCTAssertNil(Locator.Locations(fragments: ["t=one"]).time)
    }

    func testValidFragments() {
        continueAfterFailure = false
        for beginStr in ["", "1", "1.0", "1.1"] {
            for endStr in ["", ",", ",1", ",1.0", ",1.1"] {
                let val = beginStr + endStr
                if val == "" || val == "," {
                    continue
                }
                let locations = Locator.Locations(fragments: ["t=\(val)"])
                let time = locations.time
                switch time {
                case let .begin(begin):
                    XCTAssertEqual(begin, Double(beginStr))
                case let .end(end):
                    XCTAssertEqual(end, Double(endStr.replacingPrefix(",", by: "")))
                case let .interval(begin, end):
                    XCTAssertEqual(begin, Double(beginStr))
                    XCTAssertEqual(end, Double(endStr.replacingPrefix(",", by: "")))
                case nil:
                    XCTAssertNotNil(time)
                }
            }
        }
    }
}
