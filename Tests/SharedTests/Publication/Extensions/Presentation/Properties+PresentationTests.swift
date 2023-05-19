//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

class PropertiesPresentationTests: XCTestCase {
    func testGetClippedWhenAvailable() {
        XCTAssertEqual(Properties(["clipped": true]).clipped, true)
    }

    func testGetClippedWhenMissing() {
        XCTAssertNil(Properties().clipped)
    }

    func testGetFitWhenAvailable() {
        XCTAssertEqual(Properties(["fit": "cover"]).fit, .cover)
    }

    func testGetFitWhenMissing() {
        XCTAssertNil(Properties().fit)
    }

    func testGetOrientationWhenAvailable() {
        XCTAssertEqual(Properties(["orientation": "landscape"]).orientation, .landscape)
    }

    func testGetOrientationWhenMissing() {
        XCTAssertNil(Properties().orientation)
    }

    func testGetOverflowWhenAvailable() {
        XCTAssertEqual(Properties(["overflow": "scrolled"]).overflow, .scrolled)
    }

    func testGetOverflowWhenMissing() {
        XCTAssertNil(Properties().overflow)
    }

    func testGetPageWhenAvailable() {
        XCTAssertEqual(Properties(["page": "right"]).page, .right)
    }

    func testGetPageWhenMissing() {
        XCTAssertNil(Properties().page)
    }

    func testGetSpreadWhenAvailable() {
        XCTAssertEqual(Properties(["spread": "both"]).spread, .both)
    }

    func testGetSpreadWhenMissing() {
        XCTAssertNil(Properties().spread)
    }
}
