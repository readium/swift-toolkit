//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest

import ReadiumShared

@testable import ReadiumOPDS

#if !SWIFT_PACKAGE
    extension Bundle {
        static let module = Bundle(for: readium_opds1_1_test.self)
    }
#endif

class readium_opds1_1_test: XCTestCase {
    var feed: Feed!

    override func setUp() {
        super.setUp()

        continueAfterFailure = false

        guard let fileURL = Bundle.module.url(forResource: "Samples/wiki_1_1", withExtension: "opds") else {
            XCTFail("Unable to locate test file")
            return
        }

        do {
            let opdsData = try Data(contentsOf: fileURL)
            feed = try OPDS1Parser.parse(xmlData: opdsData, url: URL(string: "http://test.com")!, response: HTTPURLResponse()).feed
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
        XCTAssertEqual(feed.links.count, 4)
        XCTAssertEqual(feed.links[0].rels, ["related"])
        XCTAssertEqual(feed.links[1].mediaType, MediaType("application/atom+xml;profile=opds-catalog;kind=acquisition")!)
        XCTAssertEqual(feed.links[2].href, "http://test.com/opds-catalogs/root.xml")
        // TODO: add more tests...
    }

    func testPublications() {
        XCTAssertEqual(feed.publications.count, 2)
        XCTAssertEqual(feed.publications[0].metadata.title, "Bob, Son of Bob")
        // TODO: add more tests...
    }
}
