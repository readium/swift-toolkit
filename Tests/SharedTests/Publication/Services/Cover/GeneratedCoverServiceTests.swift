//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
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
        let expectedLinks = [Link(href: "~readium/cover", mediaType: .png, rels: [.cover])]
        XCTAssertEqual(GeneratedCoverService(cover: cover).links, expectedLinks)
        XCTAssertEqual(GeneratedCoverService(makeCover: { .success(self.cover) }).links, expectedLinks)
    }

    /// `GeneratedCoverService` serves the provided cover with `get()`.
    func testGetCover() async throws {
        for service in [
            GeneratedCoverService(cover: cover),
            GeneratedCoverService(makeCover: { .success(self.cover) }),
        ] {
            let resource = try XCTUnwrap(service.get(AnyURL(string: "~readium/cover")!))
            let result = await resource.read().map(UIImage.init)
            AssertImageEqual(result, .success(cover))
        }
    }
}
