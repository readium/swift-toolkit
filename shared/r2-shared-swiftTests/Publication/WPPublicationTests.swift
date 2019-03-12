//
//  WPPublicationTests.swift
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

class WPPublicationTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? WPPublication(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"]
                ]
            ]),
            WPPublication(
                metadata: WPMetadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? WPPublication(json: [
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
                "page-list": [
                    ["href": "/page1.html"],
                ],
                "landmarks": [
                    ["href": "/landmark.html"],
                ],
                "loa": [
                    ["href": "/audio.mp3"],
                ],
                "loi": [
                    ["href": "/image.jpg"],
                ],
                "lot": [
                    ["href": "/table.html"],
                ],
                "lov": [
                    ["href": "/video.mov"],
                ],
                "sub": [
                    "links": [
                        ["href": "/sublink"]
                    ]
                ]
            ]),
            WPPublication(
                context: ["https://readium.org/webpub-manifest/context.jsonld"],
                metadata: WPMetadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")],
                resources: [Link(href: "/image.png", type: "image/png")],
                toc: [Link(href: "/cover.html"), Link(href: "/chap1.html")],
                pageList: [Link(href: "/page1.html")],
                landmarks: [Link(href: "/landmark.html")],
                loa: [Link(href: "/audio.mp3")],
                loi: [Link(href: "/image.jpg")],
                lot: [Link(href: "/table.html")],
                lov: [Link(href: "/video.mov")],
                subcollections: [WPSubcollection(role: "sub", links: [Link(href: "/sublink")])]
            )
        )
    }
    
    func testParseContextAsArray() {
        XCTAssertEqual(
            try? WPPublication(json: [
                "@context": ["context1", "context2"],
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"]
                ]
                ]),
            WPPublication(
                context: ["context1", "context2"],
                metadata: WPMetadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try WPPublication(json: ""))
    }
    
    func testParseJSONRequiresMetadata() {
        XCTAssertThrowsError(try WPPublication(json: [
            "links": [
                ["href": "/manifest.json", "rel": "self"]
            ],
            "readingOrder": [
                ["href": "/chap1.html", "type": "text/html"]
            ]
        ]))
    }
    
    func testParseJSONRequiresLinks() {
        XCTAssertThrowsError(try WPPublication(json: [
            "metadata": ["title": "Title"],
            "readingOrder": [
                ["href": "/chap1.html", "type": "text/html"]
            ]
        ]))
    }
    
    func testParseJSONRequiresReadingOrder() {
        XCTAssertThrowsError(try WPPublication(json: [
            "metadata": ["title": "Title"],
            "links": [
                ["href": "/manifest.json", "rel": "self"]
            ]
        ]))
    }
    
    func testParseJSONSpineAsReadingOrder() {
        // `readerOrder` used to be `spine`, so we parse `spine` as a fallback.
        XCTAssertEqual(
            try? WPPublication(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "spine": [
                    ["href": "/chap1.html", "type": "text/html"]
                ]
            ]),
            WPPublication(
                metadata: WPMetadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
                    
    func testParseJSONIgnoresLinksWithoutRel() {
        XCTAssertEqual(
            try? WPPublication(json: [
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
            WPPublication(
                metadata: WPMetadata(title: "Title"),
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
            try WPPublication(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"],
                    ["href": "/chap2.html"]
                ]
            ]),
            WPPublication(
                metadata: WPMetadata(title: "Title"),
                links: [
                    Link(href: "/manifest.json", rels: ["self"]),
                ],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
    
    func testParseJSONIgnoresRessourcesWithoutType() {
        XCTAssertEqual(
            try WPPublication(json: [
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
            WPPublication(
                metadata: WPMetadata(title: "Title"),
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
            WPPublication(
                metadata: WPMetadata(title: "Title"),
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
            WPPublication(
                context: ["https://readium.org/webpub-manifest/context.jsonld"],
                metadata: WPMetadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")],
                resources: [Link(href: "/image.png", type: "image/png")],
                toc: [Link(href: "/cover.html"), Link(href: "/chap1.html")],
                pageList: [Link(href: "/page1.html")],
                landmarks: [Link(href: "/landmark.html")],
                loa: [Link(href: "/audio.mp3")],
                loi: [Link(href: "/image.jpg")],
                lot: [Link(href: "/table.html")],
                lov: [Link(href: "/video.mov")],
                subcollections: [WPSubcollection(role: "sub", links: [Link(href: "/sublink")])]
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
                "page-list": [
                    ["href": "/page1.html", "templated": false],
                ],
                "landmarks": [
                    ["href": "/landmark.html", "templated": false],
                ],
                "loa": [
                    ["href": "/audio.mp3", "templated": false],
                ],
                "loi": [
                    ["href": "/image.jpg", "templated": false],
                ],
                "lot": [
                    ["href": "/table.html", "templated": false],
                ],
                "lov": [
                    ["href": "/video.mov", "templated": false],
                ],
                "sub": [
                    "links": [
                        ["href": "/sublink", "templated": false]
                    ]
                ]
            ]
        )
    }
    
    func testGetFullJSONData() {
        XCTAssertEqual(
            WPPublication(
                context: ["https://readium.org/webpub-manifest/context.jsonld"],
                metadata: WPMetadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: ["self"])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")],
                resources: [Link(href: "/image.png", type: "image/png")],
                toc: [Link(href: "/cover.html"), Link(href: "/chap1.html")],
                pageList: [Link(href: "/page1.html")],
                landmarks: [Link(href: "/landmark.html")],
                loa: [Link(href: "/audio.mp3")],
                loi: [Link(href: "/image.jpg")],
                lot: [Link(href: "/table.html")],
                lov: [Link(href: "/video.mov")]
            ).jsonString!,
            """
            {"@context":["https://readium.org/webpub-manifest/context.jsonld"],"landmarks":[{"href":"/landmark.html","templated":false}],"links":[{"href":"/manifest.json","rel":["self"],"templated":false}],"loa":[{"href":"/audio.mp3","templated":false}],"loi":[{"href":"/image.jpg","templated":false}],"lot":[{"href":"/table.html","templated":false}],"lov":[{"href":"/video.mov","templated":false}],"metadata":{"readingProgression":"auto","title":"Title"},"page-list":[{"href":"/page1.html","templated":false}],"readingOrder":[{"href":"/chap1.html","templated":false,"type":"text/html"}],"resources":[{"href":"/image.png","templated":false,"type":"image/png"}],"toc":[{"href":"/cover.html","templated":false},{"href":"/chap1.html","templated":false}]}
            """
        )
    }
    
}
