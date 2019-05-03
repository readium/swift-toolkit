//
//  EPUBPropertiesTests.swift
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

class EPUBPropertiesTests: XCTestCase {
    
    var sut: Properties!
    
    override func setUp() {
        sut = Properties()
    }
    
    func testNoContains() {
        XCTAssertEqual(sut.contains, [])
    }
    
    func testContains() {
        sut.otherProperties["contains"] = ["mathml", "onix"]
        
        XCTAssertEqual(sut.contains, ["mathml", "onix"])
    }
    
    func testNoLayout() {
        XCTAssertNil(sut.layout)
    }
    
    func testLayout() {
        sut.otherProperties["layout"] = "fixed"
        
        XCTAssertEqual(sut.layout, .fixed)
    }
    
    func testNoMediaOverlay() {
        XCTAssertNil(sut.mediaOverlay)
    }
    
    func testMediaOverlay() {
        sut.otherProperties["media-overlay"] = "http://uri"
        
        XCTAssertEqual(sut.mediaOverlay, "http://uri")
    }
    
    func testNoOverflow() {
        XCTAssertNil(sut.overflow)
    }
    
    func testOverflow() {
        sut.otherProperties["overflow"] = "scrolled-continuous"
        
        XCTAssertEqual(sut.overflow, .scrolledContinuous)
    }
    
    func testNoSpread() {
        XCTAssertNil(sut.spread)
    }
    
    func testSpread() {
        sut.otherProperties["spread"] = "landscape"
        
        XCTAssertEqual(sut.spread, .landscape)
    }
    
    func testNoEncryption() {
        XCTAssertNil(sut.encryption)
    }
    
    func testEncryption() {
        sut.otherProperties["encrypted"] = ["algorithm": "http://algo"]
        
        XCTAssertEqual(sut.encryption, EPUBEncryption(algorithm: "http://algo"))
    }

}
