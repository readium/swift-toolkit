//
//  Properties+EPUBTests.swift
//  r2-shared-swiftTests
//
//  Created by Mickaël Menu on 14.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class PropertiesEPUBTests: XCTestCase {
    
    func testNoContains() {
        let sut = Properties()
        XCTAssertEqual(sut.contains, [])
    }
    
    func testContains() {
        let sut = Properties(["contains": ["mathml", "onix"]])
        XCTAssertEqual(sut.contains, ["mathml", "onix"])
    }
    
    func testNoLayout() {
        let sut = Properties()
        XCTAssertNil(sut.layout)
    }
    
    func testLayout() {
        let sut = Properties(["layout": "fixed"])
        XCTAssertEqual(sut.layout, .fixed)
    }

}
