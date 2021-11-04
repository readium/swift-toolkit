//
//  Properties+PresentationTests.swift
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
