//
//  Copyright 2026 Readium Foundation. All rights reserved.
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
        XCTAssert(feed!.metadata.identifier == "urn:uuid:433a5d6a-0b8c-4933-af65-4ca4f02763eb")
        XCTAssert(feed!.metadata.title == "Unpopular Publications")
        // TODO: add more tests...
    }

    func testLinks() {
        XCTAssertEqual(feed.links.count, 5)

        // Has a "related" link
        let expectedRelatedLink = Link(
            href: "http://test.com/opds-catalogs/vampire.farming.xml",
            mediaType: MediaType("application/atom+xml;profile=opds-catalog;kind=acquisition")!,
            rels: ["related"]
        )
        let relatedLink = feed?.links.first { $0.rels.contains("related") }
        XCTAssertEqual(relatedLink, expectedRelatedLink)

        // Has a "self" link
        let expectedSelfLink = Link(
            href: "http://test.com/opds-catalogs/unpopular.xml",
            mediaType: MediaType("application/atom+xml;profile=opds-catalog;kind=acquisition")!,
            rels: ["self"]
        )
        let selfLink = feed?.links.first { $0.rels.contains("self") }
        XCTAssertEqual(selfLink, expectedSelfLink)

        // Has a "start" link
        let expectedStartLink = Link(
            href: "http://test.com/opds-catalogs/root.xml",
            mediaType: MediaType("application/atom+xml;profile=opds-catalog;kind=navigation")!,
            rels: ["start"]
        )
        let startLink = feed?.links.first { $0.rels.contains("start") }
        XCTAssertEqual(startLink, expectedStartLink)

        // Has an "up" link
        let expectedUpLink = Link(
            href: "http://test.com/opds-catalogs/root.xml",
            mediaType: MediaType("application/atom+xml;profile=opds-catalog;kind=navigation")!,
            rels: ["up"]
        )
        let upLink = feed?.links.first { $0.rels.contains("up") }
        XCTAssertEqual(upLink, expectedUpLink)

        // Has an "icon" link
        let expectedIconLink = Link(
            href: "http://test.com/images/favicon.ico?t=1516986276",
            rels: ["icon"]
        )
        let iconLink = feed?.links.first { $0.rels.contains("icon") }
        XCTAssertEqual(iconLink, expectedIconLink)

        // TODO: add more tests...
    }

    func testPublications() {
        XCTAssertEqual(feed.publications.count, 2)
        XCTAssertEqual(feed.publications[0].metadata.title, "Bob, Son of Bob")
        // TODO: add more tests...
    }
}
