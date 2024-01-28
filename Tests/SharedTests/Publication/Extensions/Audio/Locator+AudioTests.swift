//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
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
    for offsetStr in ["", "1", "1.0", "1.1"] {
      for durationStr in ["", ",", ",1", ",1.0", ",1.1"] {
        let val = offsetStr + durationStr
        if val == "" || val == "," {
          continue
        }
        let locations = Locator.Locations(fragments: ["t=\(val)"])
        let time = locations.time
        switch time {
        case let .offset(offset):
          XCTAssertEqual(offset, Double(offsetStr))
        case let .duration(duration):
          XCTAssertEqual(duration, Double(durationStr.replacingPrefix(",", by: "")))
        case let .range(offset, duration):
          XCTAssertEqual(offset, Double(offsetStr))
          XCTAssertEqual(duration, Double(durationStr.replacingPrefix(",", by: "")))
        case nil:
          XCTAssertNotNil(time)
        }
      }
    }
  }
}
