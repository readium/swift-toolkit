//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class PropertiesEPUBTests: XCTestCase {
    func testNoContains() {
        let sut = Properties()
        XCTAssertEqual(sut.contains, [])
    }

    func testContains() {
        let sut = Properties(["contains": ["mathml", "onix"]])
        XCTAssertEqual(sut.contains, ["mathml", "onix"])
    }
}
