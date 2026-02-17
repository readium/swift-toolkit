//
//  Copyright 2026 Readium Foundation. All rights reserved.
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
    func testLinks() throws {
        let expectedLinks = [Link(href: "~readium/cover", mediaType: .png, rels: [.cover])]
        let cover = cover
        XCTAssertEqual(try GeneratedCoverService(cover: XCTUnwrap(cover)).links, expectedLinks)
        XCTAssertEqual(GeneratedCoverService(makeCover: { [cover] in .success(cover!) }).links, expectedLinks)
    }

    /// `GeneratedCoverService` serves the provided cover with `get()`.
    func testGetCover() async throws {
        let cover = try XCTUnwrap(cover)
        for service in [
            GeneratedCoverService(cover: cover),
            GeneratedCoverService(makeCover: { .success(cover) }),
        ] {
            let resource = try XCTUnwrap(try service.get(XCTUnwrap(AnyURL(string: "~readium/cover"))))
            let result = await resource.read().map(UIImage.init)
            AssertImageEqual(result, .success(cover))
        }
    }
}
