//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

class GeneratedCoverServiceTests: XCTestCase {
    let fixtures = Fixtures(path: "Publication/Services")
    var cover: UIImage!

    override func setUpWithError() throws {
        let coverURL = fixtures.url(for: "cover.jpg")
        cover = UIImage(contentsOfFile: coverURL.path)!
    }

    /// `GeneratedCoverService` adds a custom `Link` with `cover` rel in `links`.
    func testLinks() {
        let expectedLinks = [Link(href: "/~readium/cover", type: "image/png", rels: [.cover])]
        XCTAssertEqual(GeneratedCoverService(cover: cover).links, expectedLinks)
        XCTAssertEqual(GeneratedCoverService(makeCover: { self.cover }).links, expectedLinks)
    }

    /// `GeneratedCoverService` serves the provided cover with `get()`.
    func testGetCover() throws {
        for service in [
            GeneratedCoverService(cover: cover),
            GeneratedCoverService(makeCover: { self.cover }),
        ] {
            let resource = try XCTUnwrap(service.get(link: Link(href: "/~readium/cover")))
            XCTAssertEqual(resource.link, Link(href: "/~readium/cover", type: "image/png", rels: [.cover], height: 800, width: 598))
            try AssertImageEqual(resource.read().map(UIImage.init).get(), cover)
        }
    }
}
