//
//  WebPublicationTests.swift
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

class WebPublicationTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? WebPublication(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"]
                ]
            ]),
            WebPublication(
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? WebPublication(json: [
                "@context": "https://readium.org/webpub-manifest/context.jsonld",
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"]
                ],
                "resources": [
                    ["href": "/image.png", "type": "image/png"]
                ],
                "toc": [
                    ["href": "/cover.html"],
                    ["href": "/chap1.html"]
                ],
                "sub": [
                    "links": [
                        ["href": "/sublink"]
                    ]
                ]
            ]),
            WebPublication(
                context: ["https://readium.org/webpub-manifest/context.jsonld"],
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")],
                resources: [Link(href: "/image.png", type: "image/png")],
                tableOfContents: [Link(href: "/cover.html"), Link(href: "/chap1.html")],
                otherCollections: [PublicationCollection(role: "sub", links: [Link(href: "/sublink")])]
            )
        )
    }
    
    func testParseContextAsArray() {
        XCTAssertEqual(
            try? WebPublication(json: [
                "@context": ["context1", "context2"],
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"]
                ]
                ]),
            WebPublication(
                context: ["context1", "context2"],
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try WebPublication(json: ""))
    }
    
    func testParseJSONRequiresMetadata() {
        XCTAssertThrowsError(try WebPublication(json: [
            "links": [
                ["href": "/manifest.json", "rel": "self"]
            ],
            "readingOrder": [
                ["href": "/chap1.html", "type": "text/html"]
            ]
        ]))
    }
    
    func testParseJSONSpineAsReadingOrder() {
        // `readerOrder` used to be `spine`, so we parse `spine` as a fallback.
        XCTAssertEqual(
            try? WebPublication(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "spine": [
                    ["href": "/chap1.html", "type": "text/html"]
                ]
            ]),
            WebPublication(
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
                    
    func testParseJSONIgnoresLinksWithoutRel() {
        XCTAssertEqual(
            try? WebPublication(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"],
                    ["href": "/withrel", "rel": "withrel"],
                    ["href": "/withoutrel"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"]
                ]
            ]),
            WebPublication(
                metadata: Metadata(title: "Title"),
                links: [
                    Link(href: "/manifest.json", rels: ["self"]),
                    Link(href: "/withrel", rels: ["withrel"])
                ],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
    
    func testParseJSONIgnoresReadingOrderWithoutType() {
        XCTAssertEqual(
            try WebPublication(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"],
                    ["href": "/chap2.html"]
                ]
            ]),
            WebPublication(
                metadata: Metadata(title: "Title"),
                links: [
                    Link(href: "/manifest.json", rels: ["self"]),
                ],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
    
    func testParseJSONIgnoresRessourcesWithoutType() {
        XCTAssertEqual(
            try WebPublication(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"]
                ],
                "resources": [
                    ["href": "/withtype", "type": "text/html"],
                    ["href": "/withouttype"]
                ]
            ]),
            WebPublication(
                metadata: Metadata(title: "Title"),
                links: [
                    Link(href: "/manifest.json", rels: ["self"]),
                ],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")],
                resources: [Link(href: "/withtype", type: "text/html")]
            )
        )
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            WebPublication(
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
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
    
    func testGetFullJSON() {
        AssertJSONEqual(
            WebPublication(
                context: ["https://readium.org/webpub-manifest/context.jsonld"],
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")],
                resources: [Link(href: "/image.png", type: "image/png")],
                tableOfContents: [Link(href: "/cover.html"), Link(href: "/chap1.html")],
                otherCollections: [PublicationCollection(role: "sub", links: [Link(href: "/sublink")])]
            ).json,
            [
                "@context": ["https://readium.org/webpub-manifest/context.jsonld"],
                "metadata": ["title": "Title", "readingProgression": "auto"],
                "links": [
                    ["href": "/manifest.json", "rel": ["self"], "templated": false]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html", "templated": false]
                ],
                "resources": [
                    ["href": "/image.png", "type": "image/png", "templated": false]
                ],
                "toc": [
                    ["href": "/cover.html", "templated": false],
                    ["href": "/chap1.html", "templated": false]
                ],
                "sub": [
                    "links": [
                        ["href": "/sublink", "templated": false]
                    ]
                ]
            ]
        )
    }
    
    func testGetFullManifest() {
        XCTAssertEqual(
            WebPublication(
                context: ["https://readium.org/webpub-manifest/context.jsonld"],
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")],
                resources: [Link(href: "/image.png", type: "image/png")],
                tableOfContents: [Link(href: "/cover.html"), Link(href: "/chap1.html")]
            ).manifest,
            """
            {"@context":["https://readium.org/webpub-manifest/context.jsonld"],"links":[{"href":"/manifest.json","rel":["self"],"templated":false}],"metadata":{"readingProgression":"auto","title":"Title"},"readingOrder":[{"href":"/chap1.html","templated":false,"type":"text/html"}],"resources":[{"href":"/image.png","templated":false,"type":"image/png"}],"toc":[{"href":"/cover.html","templated":false},{"href":"/chap1.html","templated":false}]}
            """.data(using: .utf8)
        )
    }
    
}
