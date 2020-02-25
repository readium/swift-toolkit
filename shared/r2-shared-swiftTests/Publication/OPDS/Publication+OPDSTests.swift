//
//  Publication+OPDSTests.swift
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

class PublicationOPDSTests: XCTestCase {
    
    var sut: Publication!
    
    override func setUp() {
        sut = Publication(metadata: Metadata(title: ""), links: [], readingOrder: [])
    }
    
    func testNoImages() {
        XCTAssertEqual(sut.images, [])
    }
    
    func testImages() {
        sut.otherCollections.append(
            PublicationCollection(role: "images", links: [Link(href: "/image.png")])
        )
        
        XCTAssertEqual(
            sut.images,
            [Link(href: "/image.png")]
        )
    }

}
