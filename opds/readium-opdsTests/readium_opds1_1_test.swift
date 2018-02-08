//
//  readium_opdsTests.swift
//  readium-opdsTests
//
//  Created by Alexandre Camilleri on 10/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import XCTest

import AEXML
import R2Shared

@testable import ReadiumOPDS

class readium_opds1_1_test: XCTestCase {
    var feed: Feed?

    override func setUp() {
        super.setUp()

        continueAfterFailure = false

        let testBundle = Bundle(for: type(of: self))
        guard let fileURL = testBundle.url(forResource: "wiki_1_1", withExtension: "opds") else {
            XCTFail("Unable to locate test file")
            return
        }

        do {
            let opdsData = try Data(contentsOf: fileURL)
            feed = try OPDSParser.parse(xmlData: opdsData)
            XCTAssert(feed != nil)
        } catch {
            XCTFail(error.localizedDescription)
        }

        continueAfterFailure = true
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testMetadata() {
        XCTAssert(feed!.metadata.title == "Unpopular Publications")
        // TODO: add more tests...
    }

    func testLinks() {
        XCTAssert(feed!.links.count == 4)
        XCTAssert(feed!.links[0].rel.count == 1 && feed!.links[0].rel[0] == "related")
        XCTAssert(feed!.links[1].typeLink == "application/atom+xml;profile=opds-catalog;kind=acquisition")
        XCTAssert(feed!.links[2].href == "/opds-catalogs/root.xml")
        // TODO: add more tests...
    }

    func testPublications() {
        XCTAssert(feed!.publications.count == 2)
        XCTAssert(feed!.publications[0].metadata.multilangTitle?.singleString == "Bob, Son of Bob")
        // TODO: add more tests...
    }
}
