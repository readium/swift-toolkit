//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
@testable import R2Shared

class ArchiveFetcherTests: XCTestCase {
    
    let fixtures = Fixtures(path: "Fetcher")
    var fetcher: ArchiveFetcher!

    override func setUpWithError() throws {
        let url = fixtures.url(for: "epub.epub")
        fetcher = try ArchiveFetcher(archive: DefaultArchiveFactory().open(url: url, password: nil).get())
    }
    
    func testLinks() {
        XCTAssertEqual(
            fetcher.links,
            [
                ("/mimetype", nil, 20, false),
                ("/EPUB/cover.xhtml", "text/html", 259, true),
                ("/EPUB/css/epub.css", "text/css", 595, true),
                ("/EPUB/css/nav.css", "text/css", 306, true),
                ("/EPUB/images/cover.png", "image/png", 35809, true),
                ("/EPUB/nav.xhtml", "text/html", 2293, true),
                ("/EPUB/package.opf", nil, 773, true),
                ("/EPUB/s04.xhtml", "text/html", 118269, true),
                ("/EPUB/toc.ncx", nil, 1697, true),
                ("/META-INF/container.xml", "application/xml", 176, true)
            ].map { href, type, entryLength, isCompressed in
                Link(href: href, type: type, properties: .init([
                    "compressedLength": (isCompressed ? entryLength : nil) as Any, // legacy
                    "archive": [
                        "entryLength": entryLength,
                        "isEntryCompressed": isCompressed,
                    ] as Any
                ]))
            }
        )
    }
    
    func testReadEntryFully() {
        let resource = fetcher.get(Link(href: "/mimetype"))
        let result = resource.read()
        let string = String(data: try! result.get(), encoding: .ascii)
        XCTAssertEqual(string, "application/epub+zip")
    }
    
    func testReadEntryRange() {
        let resource = fetcher.get(Link(href: "/mimetype"))
        let result = resource.read(range: 0..<11)
        let string = String(data: try! result.get(), encoding: .ascii)
        XCTAssertEqual(string, "application")
    }

    func testOutOfRangeIndexesAreClampedToAvailableLength() {
        let resource = fetcher.get(Link(href: "/mimetype"))
        let result = resource.read(range: 5..<60)
        let string = String(data: try! result.get(), encoding: .ascii)
        XCTAssertEqual(string, "cation/epub+zip")
    }
    
    func testReadingMissingEntryReturnsNotFound() {
        let resource = fetcher.get(Link(href: "/unknown"))
        let result = resource.read()
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(ResourceError.notFound(nil), error as? ResourceError)
        }
    }
    
    func testComputingLength() {
        let resource = fetcher.get(Link(href: "/mimetype"))
        XCTAssertEqual(try! resource.length.get(), 20)
    }
    
    func testComputingLengthForMissingEntryReturnsNotFound() {
        let resource = fetcher.get(Link(href: "/unknown"))
        let result = resource.length
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(ResourceError.notFound(nil), error as? ResourceError)
        }
    }
    
    func testAddsCompressedLengthToLink() {
        let resource = fetcher.get(Link(href: "/EPUB/css/epub.css"))
        AssertJSONEqual(
            resource.link.properties.json,
            [
                "archive": [
                    "entryLength": 595,
                    "isEntryCompressed": true
                ],
                "compressedLength": 595
            ]
        )
    }
    
    /// When the HREF contains query parameters, the fetcher should first be able to remove them as
    /// a fallback.
    func testHREFWithQueryParameters() {
        let resource = fetcher.get(Link(href: "/mimetype?query=param"))
        let result = resource.readAsString(encoding: .ascii)
        XCTAssertEqual(result.getOrNil(), "application/epub+zip")
    }
    
    /// When the HREF contains an anchor, the fetcher should first be able to remove them as
    /// a fallback.
    func testHREFWithAnchor() {
        let resource = fetcher.get(Link(href: "/mimetype#anchor"))
        let result = resource.readAsString(encoding: .ascii)
        XCTAssertEqual(result.getOrNil(), "application/epub+zip")
    }
}
