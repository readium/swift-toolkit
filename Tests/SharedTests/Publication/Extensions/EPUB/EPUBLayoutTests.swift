//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class EPUBLayoutTests: XCTestCase {
    func testParseLayout() {
        XCTAssertEqual(EPUBLayout(rawValue: "fixed"), .fixed)
        XCTAssertEqual(EPUBLayout(rawValue: "reflowable"), .reflowable)
        XCTAssertNil(EPUBLayout(rawValue: "foobar"))
    }

    func testGetLayoutValue() {
        XCTAssertEqual("fixed", EPUBLayout.fixed.rawValue)
        XCTAssertEqual("reflowable", EPUBLayout.reflowable.rawValue)
    }
}
