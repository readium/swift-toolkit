//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class ManifestTests: XCTestCase {
    let fixtures = Fixtures(path: "Publication")

    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Manifest(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "manifest.json", "rel": "self"],
                ],
                "readingOrder": [
                    ["href": "chap1.html", "type": "text/html"],
                ],
            ] as [String: Any]),
            Manifest(
                metadata: Metadata(title: "Title"),
                links: [Link(href: "manifest.json", rels: [.self])],
                readingOrder: [Link(href: "chap1.html", mediaType: .html)]
            )
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            try? Manifest(json: [
                "@context": "https://readium.org/webpub-manifest/context.jsonld",
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "manifest.json", "rel": "self"],
                ],
                "readingOrder": [
                    ["href": "chap1.html", "type": "text/html"],
                ],
                "resources": [
                    ["href": "image.png", "type": "image/png"],
                ],
                "toc": [
                    ["href": "cover.html"],
                    ["href": "chap1.html"],
                ],
                "sub": [
                    "links": [
                        ["href": "sublink"],
                    ],
                ],
            ] as [String: Any]),
            Manifest(
                context: ["https://readium.org/webpub-manifest/context.jsonld"],
                metadata: Metadata(title: "Title"),
                links: [Link(href: "manifest.json", rels: [.self])],
                readingOrder: [Link(href: "chap1.html", mediaType: .html)],
                resources: [Link(href: "image.png", mediaType: .png)],
                tableOfContents: [Link(href: "cover.html"), Link(href: "chap1.html")],
                subcollections: ["sub": [PublicationCollection(links: [Link(href: "sublink")])]]
            )
        )
    }

    func testParseContextAsArray() {
        XCTAssertEqual(
            try? Manifest(json: [
                "@context": ["context1", "context2"],
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "manifest.json", "rel": "self"],
                ],
                "readingOrder": [
                    ["href": "chap1.html", "type": "text/html"],
                ],
            ] as [String: Any]),
            Manifest(
                context: ["context1", "context2"],
                metadata: Metadata(title: "Title"),
                links: [Link(href: "manifest.json", rels: [.self])],
                readingOrder: [Link(href: "chap1.html", mediaType: .html)]
            )
        )
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Manifest(json: ""))
    }

    func testParseJSONRequiresMetadata() {
        XCTAssertThrowsError(try Manifest(json: [
            "links": [
                ["href": "manifest.json", "rel": "self"],
            ],
            "readingOrder": [
                ["href": "chap1.html", "type": "text/html"],
            ],
        ]))
    }

    func testParseJSONSpineAsReadingOrder() {
        // `readingOrder` used to be `spine`, so we parse `spine` as a fallback.
        XCTAssertEqual(
            try? Manifest(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "manifest.json", "rel": "self"],
                ],
                "spine": [
                    ["href": "chap1.html", "type": "text/html"],
                ],
            ] as [String: Any]),
            Manifest(
                metadata: Metadata(title: "Title"),
                links: [Link(href: "manifest.json", rels: [.self])],
                readingOrder: [Link(href: "chap1.html", mediaType: .html)]
            )
        )
    }

    func testParseJSONIgnoresReadingOrderWithoutType() {
        XCTAssertEqual(
            try Manifest(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "manifest.json", "rel": "self"],
                ],
                "readingOrder": [
                    ["href": "chap1.html", "type": "text/html"],
                    ["href": "chap2.html"],
                ],
            ] as [String: Any]),
            Manifest(
                metadata: Metadata(title: "Title"),
                links: [
                    Link(href: "manifest.json", rels: [.self]),
                ],
                readingOrder: [Link(href: "chap1.html", mediaType: .html)]
            )
        )
    }

    func testParseJSONIgnoresRessourcesWithoutType() {
        XCTAssertEqual(
            try Manifest(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "manifest.json", "rel": "self"],
                ],
                "readingOrder": [
                    ["href": "chap1.html", "type": "text/html"],
                ],
                "resources": [
                    ["href": "withtype", "type": "text/html"],
                    ["href": "withouttype"],
                ],
            ] as [String: Any]),
            Manifest(
                metadata: Metadata(title: "Title"),
                links: [
                    Link(href: "manifest.json", rels: [.self]),
                ],
                readingOrder: [Link(href: "chap1.html", mediaType: .html)],
                resources: [Link(href: "withtype", mediaType: .html)]
            )
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            Manifest(
                metadata: Metadata(title: "Title"),
                links: [Link(href: "manifest.json", rels: [.self])],
                readingOrder: [Link(href: "chap1.html", mediaType: .html)]
            ).json,
            [
                "metadata": ["title": "Title", "readingProgression": "auto"],
                "links": [
                    ["href": "manifest.json", "rel": ["self"], "templated": false] as [String: Any],
                ],
                "readingOrder": [
                    ["href": "chap1.html", "type": "text/html", "templated": false] as [String: Any],
                ],
            ] as [String: Any]
        )
    }

    func testGetFullJSON() {
        AssertJSONEqual(
            Manifest(
                context: ["https://readium.org/webpub-manifest/context.jsonld"],
                metadata: Metadata(title: "Title"),
                links: [Link(href: "manifest.json", rels: [.self])],
                readingOrder: [Link(href: "chap1.html", mediaType: .html)],
                resources: [Link(href: "image.png", mediaType: .png)],
                tableOfContents: [Link(href: "cover.html"), Link(href: "chap1.html")],
                subcollections: ["sub": [PublicationCollection(links: [Link(href: "sublink")])]]
            ).json,
            [
                "@context": ["https://readium.org/webpub-manifest/context.jsonld"],
                "metadata": ["title": "Title", "readingProgression": "auto"],
                "links": [
                    ["href": "manifest.json", "rel": ["self"], "templated": false] as [String: Any],
                ],
                "readingOrder": [
                    ["href": "chap1.html", "type": "text/html", "templated": false] as [String: Any],
                ],
                "resources": [
                    ["href": "image.png", "type": "image/png", "templated": false] as [String: Any],
                ],
                "toc": [
                    ["href": "cover.html", "templated": false] as [String: Any],
                    ["href": "chap1.html", "templated": false],
                ],
                "sub": [
                    "links": [
                        ["href": "sublink", "templated": false] as [String: Any],
                    ],
                ],
            ] as [String: Any]
        )
    }

    func testLinkWithRelInReadingOrder() {
        XCTAssertEqual(
            makeManifest(readingOrder: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1"),
            ]).linkWithRel("rel1")?.href,
            "l2"
        )
    }

    func testLinkWithRelInLinks() {
        XCTAssertEqual(
            makeManifest(links: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1"),
            ]).linkWithRel("rel1")?.href,
            "l2"
        )
    }

    func testLinkWithRelInResources() {
        XCTAssertEqual(
            makeManifest(resources: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1"),
            ]).linkWithRel("rel1")?.href,
            "l2"
        )
    }

    func testLinksWithRel() {
        XCTAssertEqual(
            makeManifest(
                links: [
                    Link(href: "l1"),
                    Link(href: "l2", rel: "rel1"),
                ],
                readingOrder: [
                    Link(href: "l3"),
                    Link(href: "l4", rel: "rel1"),
                ],
                resources: [
                    Link(href: "l5", alternates: [
                        Link(href: "alternate", rel: "rel1"),
                    ]),
                    Link(href: "l6", rel: "rel1"),
                ]
            ).linksWithRel("rel1"),
            [
                Link(href: "l4", rel: "rel1"),
                Link(href: "l6", rel: "rel1"),
                Link(href: "l2", rel: "rel1"),
            ]
        )
    }

    func testLinksWithRelEmpty() {
        XCTAssertEqual(
            makeManifest(resources: [
                Link(href: "l1"),
                Link(href: "l2"),
            ]).linksWithRel("rel1"),
            []
        )
    }

    private func makeManifest(metadata: Metadata = Metadata(title: ""), links: [Link] = [], readingOrder: [Link] = [], resources: [Link] = []) -> Manifest {
        Manifest(metadata: metadata, links: links, readingOrder: readingOrder, resources: resources)
    }
}
