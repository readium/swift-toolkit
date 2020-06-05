//
//  PublicationManifestTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 30/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class PublicationManifestTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? PublicationManifest(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"]
                ]
            ]),
            PublicationManifest(
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? PublicationManifest(json: [
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
            PublicationManifest(
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
            try? PublicationManifest(json: [
                "@context": ["context1", "context2"],
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"]
                ]
            ]),
            PublicationManifest(
                context: ["context1", "context2"],
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try PublicationManifest(json: ""))
    }
    
    func testParseJSONRequiresMetadata() {
        XCTAssertThrowsError(try PublicationManifest(json: [
            "links": [
                ["href": "/manifest.json", "rel": "self"]
            ],
            "readingOrder": [
                ["href": "/chap1.html", "type": "text/html"]
            ]
        ]))
    }
    
    func testParseJSONSpineAsReadingOrder() {
        // `readingOrder` used to be `spine`, so we parse `spine` as a fallback.
        XCTAssertEqual(
            try? PublicationManifest(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "spine": [
                    ["href": "/chap1.html", "type": "text/html"]
                ]
            ]),
            PublicationManifest(
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
    
    func testParseJSONIgnoresReadingOrderWithoutType() {
        XCTAssertEqual(
            try PublicationManifest(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"],
                    ["href": "/chap2.html"]
                ]
            ]),
            PublicationManifest(
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
            try PublicationManifest(json: [
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
            PublicationManifest(
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
            PublicationManifest(
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
            PublicationManifest(
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
    
    func testLinkWithRelInReadingOrder() {
        XCTAssertEqual(
            makeManifest(readingOrder: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1")
            ]).link(withRel: "rel1")?.href,
            "l2"
        )
    }
    
    func testLinkWithRelInLinks() {
        XCTAssertEqual(
            makeManifest(links: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1")
            ]).link(withRel: "rel1")?.href,
            "l2"
        )
    }
    
    func testLinkWithRelInResources() {
        XCTAssertEqual(
            makeManifest(resources: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1")
            ]).link(withRel: "rel1")?.href,
            "l2"
        )
    }

    func testLinksWithRel() {
        XCTAssertEqual(
            makeManifest(
                links: [
                    Link(href: "l1"),
                    Link(href: "l2", rel: "rel1")
                ],
                readingOrder: [
                    Link(href: "l3"),
                    Link(href: "l4", rel: "rel1")
                ],
                resources: [
                    Link(href: "l5", alternates: [
                        Link(href: "alternate", rel: "rel1")
                    ]),
                    Link(href: "l6", rel: "rel1")
                ]
            ).links(withRel: "rel1"),
            [
                Link(href: "l4", rel: "rel1"),
                Link(href: "l6", rel: "rel1"),
                Link(href: "l2", rel: "rel1")
            ]
        )
    }
    
    func testLinksWithRelEmpty() {
        XCTAssertEqual(
            makeManifest(resources: [
                Link(href: "l1"),
                Link(href: "l2")
            ]).links(withRel: "rel1"),
            []
        )
    }

    private func makeManifest(metadata: Metadata = Metadata(title: ""), links: [Link] = [], readingOrder: [Link] = [], resources: [Link] = []) -> PublicationManifest {
        return PublicationManifest(metadata: metadata, links: links, readingOrder: readingOrder, resources: resources)
    }

}
