//
//  EPUBMetadataTests.swift
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

class EPUBMetadataTests: XCTestCase {
    
    var sut: Metadata!
    
    override func setUp() {
        sut = Metadata(title: "Title")
    }
    
    func testNoRendition() {
        XCTAssertNil(sut.rendition)
    }
    
    func testRendition() {
        sut.otherMetadata["rendition"] = ["layout": "fixed"]
        
        XCTAssertEqual(sut.rendition, EPUBRendition(layout: .fixed))
    }

}
