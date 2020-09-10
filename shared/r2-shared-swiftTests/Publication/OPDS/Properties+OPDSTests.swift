//
//  Properties+OPDSTests.swift
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

class PropertiesOPDSTests: XCTestCase {

    func testNoNumberOfItems() {
        let sut = Properties()
        XCTAssertNil(sut.numberOfItems)
    }
    
    func testNumberOfItems() {
        let sut = Properties(["numberOfItems": 42])
        XCTAssertEqual(sut.numberOfItems, 42)
    }
    
    func testNumberOfItemsMustBePositive() {
        let sut = Properties(["numberOfItems": -20])
        XCTAssertNil(sut.numberOfItems)
    }

    func testNoPrice() {
        let sut = Properties()
        XCTAssertNil(sut.price)
    }
    
    func testPrice() {
        let sut = Properties(["price": [
            "currency": "EUR",
            "value": 3.65
        ]])

        XCTAssertEqual(sut.price, OPDSPrice(currency: "EUR", value: 3.65))
    }

    func testNoIndirectAcquisition() {
        let sut = Properties()
        XCTAssertEqual(sut.indirectAcquisitions, [])
    }
    
    func testIndirectAcquisition() {
        let sut = Properties(["indirectAcquisition": [
            [ "type": "acqtype" ]
        ]])
        
        XCTAssertEqual(sut.indirectAcquisitions, [
            OPDSAcquisition(type: "acqtype")
        ])
    }

    func testNoHolds() {
        let sut = Properties()
        XCTAssertNil(sut.holds)
    }
    
    func testHolds() {
        let sut = Properties(["holds": [
            "total": 5
        ]])
        
        XCTAssertEqual(sut.holds, OPDSHolds(total: 5, position: nil))
    }

    func testNoCopies() {
        let sut = Properties()
        XCTAssertNil(sut.copies)
    }
    
    func testCopies() {
        let sut = Properties(["copies": [
            "total": 5
        ]])
        
        XCTAssertEqual(sut.copies, OPDSCopies(total: 5, available: nil))
    }

    func testNoAvailability() {
        let sut = Properties()
        XCTAssertNil(sut.availability)
    }
    
    func testAvailability() {
        let sut = Properties(["availability": [
            "state": "available"
        ]])
        
        XCTAssertEqual(sut.availability, OPDSAvailability(state: .available))
    }

}
