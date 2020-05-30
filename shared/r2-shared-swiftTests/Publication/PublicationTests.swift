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
    
    func testParseJSON() {
        XCTAssertEqual(
            try? Publication(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"]
                ]
            ]),
            Publication(
                manifest: PublicationManifest(
                    metadata: Metadata(title: "Title"),
                    links: [Link(href: "/manifest.json", rels: ["self"])],
                    readingOrder: [Link(href: "/chap1.html", type: "text/html")]
                )
            )
        )
    }

    func testGetJSON() {
        AssertJSONEqual(
            Publication(
                manifest: PublicationManifest(
                    metadata: Metadata(title: "Title"),
                    links: [Link(href: "/manifest.json", rels: ["self"])],
                    readingOrder: [Link(href: "/chap1.html", type: "text/html")]
                )
            ).json,
            [
                "metadata": ["title": "Title", "readingProgression": "auto"],
                "links": [
                    ["href": "/manifest.json", "rel": ["self"], "templated": false]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html", "templated": false]
                ]
            ]
        )
    }

}
