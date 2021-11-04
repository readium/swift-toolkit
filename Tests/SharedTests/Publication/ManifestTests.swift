//
//  ManifestTests.swift
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

class ManifestTests: XCTestCase {
    
    let fixtures = Fixtures(path: "Publication")
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Manifest(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"]
                ]
            ]),
            Manifest(
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: [.self])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? Manifest(json: [
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
            Manifest(
                context: ["https://readium.org/webpub-manifest/context.jsonld"],
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: [.self])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")],
                resources: [Link(href: "/image.png", type: "image/png")],
                tableOfContents: [Link(href: "/cover.html"), Link(href: "/chap1.html")],
                subcollections: ["sub": [PublicationCollection(links: [Link(href: "/sublink")])]]
            )
        )
    }
    
    func testParseContextAsArray() {
        XCTAssertEqual(
            try? Manifest(json: [
                "@context": ["context1", "context2"],
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"]
                ]
            ]),
            Manifest(
                context: ["context1", "context2"],
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: [.self])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Manifest(json: ""))
    }
    
    func testParseJSONRequiresMetadata() {
        XCTAssertThrowsError(try Manifest(json: [
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
            try? Manifest(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "spine": [
                    ["href": "/chap1.html", "type": "text/html"]
                ]
            ]),
            Manifest(
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: [.self])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
    
    func testParseJSONIgnoresReadingOrderWithoutType() {
        XCTAssertEqual(
            try Manifest(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "/manifest.json", "rel": "self"]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html"],
                    ["href": "/chap2.html"]
                ]
            ]),
            Manifest(
                metadata: Metadata(title: "Title"),
                links: [
                    Link(href: "/manifest.json", rels: [.self]),
                ],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")]
            )
        )
    }
    
    func testParseJSONIgnoresRessourcesWithoutType() {
        XCTAssertEqual(
            try Manifest(json: [
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
            Manifest(
                metadata: Metadata(title: "Title"),
                links: [
                    Link(href: "/manifest.json", rels: [.self]),
                ],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")],
                resources: [Link(href: "/withtype", type: "text/html")]
            )
        )
    }
    
    /// The `Link`s' hrefs are normalized to the `self` link for a RWPM.
    func testHrefsAreNormalizedToSelfForManifests() {
        let json: Any = fixtures.json(at: "flatland-href.json")
        
        XCTAssertEqual(
            try Manifest(json: json, isPackaged: false).readingOrder.map { $0.href },
            [
                "http://www.archive.org/download/flatland_rg_librivox/flatland_1_abbott.mp3",
                "https://readium.org/webpub-manifest/examples/Flatland/flatland_2_abbott.mp3",
                "https://readium.org/webpub-manifest/examples/Flatland/directory/flatland_2_abbott.mp3",
                "https://readium.org/flatland_3_abbott.mp3",
                "https://readium.org/directory/flatland_4_abbott.mp3",
                "https://readium.org/webpub-manifest/examples/flatland_5_abbott.mp3"
            ]
        )
    }
    
    /// The `Link`s' hrefs are normalized to `/` for a package.
    func testHrefsAreNormalizedToRootForPackages() {
        let json: Any = fixtures.json(at: "flatland-href.json")

        XCTAssertEqual(
            try Manifest(json: json, isPackaged: true).readingOrder.map { $0.href },
            [
                "http://www.archive.org/download/flatland_rg_librivox/flatland_1_abbott.mp3",
                "/flatland_2_abbott.mp3",
                "/directory/flatland_2_abbott.mp3",
                "/flatland_3_abbott.mp3",
                "/directory/flatland_4_abbott.mp3",
                "/../flatland_5_abbott.mp3"
            ]
        )
    }
    
    /// The `Link` with `self` relation is converted to an `alternate` for a package.
    func testSelfBecomesAlternateForPackages() throws {
        let json: Any = fixtures.json(at: "flatland-href.json")
        let manifest = try Manifest(json: json, isPackaged: true)
        
        XCTAssertNil(manifest.link(withRel: .self))
        XCTAssertEqual(manifest.links(withRel: .alternate), [
            Link(href: "https://readium.org/webpub-manifest/examples/Flatland/manifest.json", type: "application/audiobook+json", rels: ["other", .alternate])
        ])
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            Manifest(
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: [.self])],
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
            Manifest(
                context: ["https://readium.org/webpub-manifest/context.jsonld"],
                metadata: Metadata(title: "Title"),
                links: [Link(href: "/manifest.json", rels: [.self])],
                readingOrder: [Link(href: "/chap1.html", type: "text/html")],
                resources: [Link(href: "/image.png", type: "image/png")],
                tableOfContents: [Link(href: "/cover.html"), Link(href: "/chap1.html")],
                subcollections: ["sub": [PublicationCollection(links: [Link(href: "/sublink")])]]
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
    
    func testCopy() {
        let manifest = Manifest(
            context: ["https://readium.org/webpub-manifest/context.jsonld"],
            metadata: Metadata(title: "Title"),
            links: [Link(href: "/manifest.json", rels: [.self])],
            readingOrder: [Link(href: "/chap1.html", type: "text/html")],
            resources: [Link(href: "/image.png", type: "image/png")],
            tableOfContents: [Link(href: "/cover.html"), Link(href: "/chap1.html")],
            subcollections: ["sub": [PublicationCollection(links: [Link(href: "/sublink")])]]
        )

        AssertJSONEqual(manifest.json, manifest.copy().json)
        
        let copy = manifest.copy(
            context: ["copy-context"],
            metadata: Metadata(title: "copy-title"),
            links: [Link(href: "copy-links")],
            readingOrder: [Link(href: "copy-reading-order")],
            resources: [Link(href: "copy-resources")],
            tableOfContents: [Link(href: "copy-toc")],
            subcollections: ["copy": [PublicationCollection(links: [])]]
        )

        AssertJSONEqual(
            copy.json,
            [
                "@context": ["copy-context"],
                "metadata": [
                    "title": "copy-title",
                    "readingProgression": "auto"
                ],
                "links": [
                    ["href": "copy-links", "templated": false]
                ],
                "readingOrder": [
                    ["href": "copy-reading-order", "templated": false]
                ],
                "resources": [
                    ["href": "copy-resources", "templated": false]
                ],
                "toc": [
                    ["href": "copy-toc", "templated": false]
                ],
                "copy": [
                    "links": []
                ]
            ]
        )
    }

    private func makeManifest(metadata: Metadata = Metadata(title: ""), links: [Link] = [], readingOrder: [Link] = [], resources: [Link] = []) -> Manifest {
        return Manifest(metadata: metadata, links: links, readingOrder: readingOrder, resources: resources)
    }

}
