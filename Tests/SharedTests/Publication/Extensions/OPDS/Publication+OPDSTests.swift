//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class PublicationOPDSTests: XCTestCase {
    func testNoImages() {
        let sut = Publication(manifest: .init(metadata: Metadata(title: ""), links: [], readingOrder: []))
        XCTAssertEqual(sut.images, [])
    }

    func testImages() {
        let sut = Publication(manifest: Manifest(
            metadata: Metadata(title: ""), links: [], readingOrder: [],
            subcollections: ["images": [PublicationCollection(links: [Link(href: "/image.png")])]]
        ))

        XCTAssertEqual(
            sut.images,
            [Link(href: "/image.png")]
        )
    }
}
