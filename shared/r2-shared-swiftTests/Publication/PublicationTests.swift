//
//  PublicationTests.swift
//  r2-shared-swiftTests
//
//  Created by Mickaël Menu on 11.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class PublicationTests: XCTestCase {

    func testGetJSON() {
        XCTAssertEqual(
            Publication(
                manifest: PublicationManifest(
                    metadata: Metadata(title: "Title"),
                    links: [Link(href: "/manifest.json", rels: ["self"])],
                    readingOrder: [Link(href: "/chap1.html", type: "text/html")]
                )
            ).jsonManifest,
            serializeJSONData([
                "metadata": ["title": "Title", "readingProgression": "auto"],
                "links": [
                    ["href": "/manifest.json", "rel": ["self"], "templated": false]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html", "templated": false]
                ]
            ])
        )
    }

}
