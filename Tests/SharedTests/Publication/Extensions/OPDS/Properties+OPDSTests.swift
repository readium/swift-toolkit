//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

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
            "value": 3.65,
        ] as [String: Any]])

        XCTAssertEqual(sut.price, OPDSPrice(currency: "EUR", value: 3.65))
    }

    func testNoIndirectAcquisition() {
        let sut = Properties()
        XCTAssertEqual(sut.indirectAcquisitions, [])
    }

    func testIndirectAcquisition() {
        let sut = Properties(["indirectAcquisition": [
            ["type": "acqtype"],
        ]])

        XCTAssertEqual(sut.indirectAcquisitions, [
            OPDSAcquisition(type: "acqtype"),
        ])
    }

    func testNoHolds() {
        let sut = Properties()
        XCTAssertNil(sut.holds)
    }

    func testHolds() {
        let sut = Properties(["holds": [
            "total": 5,
        ]])

        XCTAssertEqual(sut.holds, OPDSHolds(total: 5, position: nil))
    }

    func testNoCopies() {
        let sut = Properties()
        XCTAssertNil(sut.copies)
    }

    func testCopies() {
        let sut = Properties(["copies": [
            "total": 5,
        ]])

        XCTAssertEqual(sut.copies, OPDSCopies(total: 5, available: nil))
    }

    func testNoAvailability() {
        let sut = Properties()
        XCTAssertNil(sut.availability)
    }

    func testAvailability() {
        let sut = Properties(["availability": [
            "state": "available",
        ]])

        XCTAssertEqual(sut.availability, OPDSAvailability(state: .available))
    }

    func testNoAuthenticateLink() {
        let sut = Properties()
        XCTAssertNil(sut.authenticate)
    }

    func testAuthenticateLink() {
        let sut = Properties(["authenticate": [
            "href": "https://example.com/authentication.json",
            "type": "application/opds-authentication+json",
        ]])
        XCTAssertEqual(sut.authenticate, Link(
            href: "https://example.com/authentication.json",
            mediaType: .opdsAuthentication
        ))
    }

    func testInvalidAuthenticateLink() {
        let sut = Properties(["authenticate": [
            "type": "application/opds-authentication+json",
        ]])
        XCTAssertNil(sut.authenticate)
    }
}
