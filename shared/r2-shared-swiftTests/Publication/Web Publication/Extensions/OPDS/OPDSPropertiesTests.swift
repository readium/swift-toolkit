//
//  OPDSPropertiesTests.swift
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

class OPDSPropertiesTests: XCTestCase {

    var sut: Properties!
    
    override func setUp() {
        sut = Properties()
    }

    func testNoNumberOfItems() {
        XCTAssertNil(sut.numberOfItems)
    }
    
    func testNumberOfItems() {
        sut.otherProperties["numberOfItems"] = 42

        XCTAssertEqual(sut.numberOfItems, 42)
    }
    
    func testNumberOfItemsMustBePositive() {
        sut.otherProperties["numberOfItems"] = -20
        
        XCTAssertNil(sut.numberOfItems)
    }

    func testNoPrice() {
        XCTAssertNil(sut.price)
    }
    
    func testPrice() {
        sut.otherProperties["price"] = [
            "currency": "EUR",
            "value": 3.65
        ]
        
        XCTAssertEqual(sut.price, OPDSPrice(currency: "EUR", value: 3.65))
    }

    func testNoIndirectAcquisition() {
        XCTAssertEqual(sut.indirectAcquisition, [])
    }
    
    func testIndirectAcquisition() {
        sut.otherProperties["indirectAcquisition"] = [
            [ "type": "acqtype" ]
        ]
        
        XCTAssertEqual(sut.indirectAcquisition, [
            OPDSAcquisition(type: "acqtype")
        ])
    }

}
