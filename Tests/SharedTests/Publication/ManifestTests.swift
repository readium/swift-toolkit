//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

struct ManifestTests {
    @Test func parseMinimalJSON() {
        #expect(
            (try? Manifest(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "manifest.json", "rel": "self"],
                ],
                "readingOrder": [
                    ["href": "chap1.html", "type": "text/html"],
                ],
            ] as JSONValue)) ==
                Manifest(
                    metadata: Metadata(title: "Title"),
                    links: [Link(href: "manifest.json", rels: [.self])],
                    readingOrder: [Link(href: "chap1.html", mediaType: .html)]
                )
        )
    }

    @Test func parseFullJSON() {
        #expect(
            (try? Manifest(json: [
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
            ] as JSONValue)) ==
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

    @Test func parseContextAsArray() {
        #expect(
            (try? Manifest(json: [
                "@context": ["context1", "context2"],
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "manifest.json", "rel": "self"],
                ],
                "readingOrder": [
                    ["href": "chap1.html", "type": "text/html"],
                ],
            ] as JSONValue)) ==
                Manifest(
                    context: ["context1", "context2"],
                    metadata: Metadata(title: "Title"),
                    links: [Link(href: "manifest.json", rels: [.self])],
                    readingOrder: [Link(href: "chap1.html", mediaType: .html)]
                )
        )
    }

    @Test func parseInvalidJSON() {
        #expect(throws: JSONError.self) {
            try Manifest(json: "")
        }
    }

    @Test func parseJSONRequiresMetadata() {
        #expect(throws: (any Error).self) {
            try Manifest(json: [
                "links": [
                    ["href": "manifest.json", "rel": "self"],
                ],
                "readingOrder": [
                    ["href": "chap1.html", "type": "text/html"],
                ],
            ])
        }
    }

    @Test func parseJSONSpineAsReadingOrder() {
        // `readingOrder` used to be `spine`, so we parse `spine` as a fallback.
        #expect(
            (try? Manifest(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "manifest.json", "rel": "self"],
                ],
                "spine": [
                    ["href": "chap1.html", "type": "text/html"],
                ],
            ] as JSONValue)) ==
                Manifest(
                    metadata: Metadata(title: "Title"),
                    links: [Link(href: "manifest.json", rels: [.self])],
                    readingOrder: [Link(href: "chap1.html", mediaType: .html)]
                )
        )
    }

    @Test func parseJSONIgnoresReadingOrderWithoutType() throws {
        #expect(
            try Manifest(json: [
                "metadata": ["title": "Title"],
                "links": [
                    ["href": "manifest.json", "rel": "self"],
                ],
                "readingOrder": [
                    ["href": "chap1.html", "type": "text/html"],
                    ["href": "chap2.html"],
                ],
            ] as JSONValue) ==
                Manifest(
                    metadata: Metadata(title: "Title"),
                    links: [
                        Link(href: "manifest.json", rels: [.self]),
                    ],
                    readingOrder: [Link(href: "chap1.html", mediaType: .html)]
                )
        )
    }

    @Test func parseJSONIgnoresRessourcesWithoutType() throws {
        #expect(
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
            ] as JSONValue) ==
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

    @Test func getMinimalJSON() {
        #expect(
            Manifest(
                metadata: Metadata(title: "Title"),
                links: [Link(href: "manifest.json", rels: [.self])],
                readingOrder: [Link(href: "chap1.html", mediaType: .html)]
            ).jsonObject ==
                [
                    "metadata": ["title": "Title", "readingProgression": "auto"],
                    "links": [
                        ["href": "manifest.json", "rel": ["self"], "templated": false] as JSONValue,
                    ],
                    "readingOrder": [
                        ["href": "chap1.html", "type": "text/html", "templated": false] as JSONValue,
                    ],
                ] as [String: JSONValue]
        )
    }

    @Test func getFullJSON() {
        #expect(
            Manifest(
                context: ["https://readium.org/webpub-manifest/context.jsonld"],
                metadata: Metadata(title: "Title"),
                links: [Link(href: "manifest.json", rels: [.self])],
                readingOrder: [Link(href: "chap1.html", mediaType: .html)],
                resources: [Link(href: "image.png", mediaType: .png)],
                tableOfContents: [Link(href: "cover.html"), Link(href: "chap1.html")],
                subcollections: ["sub": [PublicationCollection(links: [Link(href: "sublink")])]]
            ).jsonObject ==
                [
                    "@context": ["https://readium.org/webpub-manifest/context.jsonld"],
                    "metadata": ["title": "Title", "readingProgression": "auto"],
                    "links": [
                        ["href": "manifest.json", "rel": ["self"], "templated": false] as JSONValue,
                    ],
                    "readingOrder": [
                        ["href": "chap1.html", "type": "text/html", "templated": false] as JSONValue,
                    ],
                    "resources": [
                        ["href": "image.png", "type": "image/png", "templated": false] as JSONValue,
                    ],
                    "toc": [
                        ["href": "cover.html", "templated": false] as JSONValue,
                        ["href": "chap1.html", "templated": false],
                    ],
                    "sub": [
                        "links": [
                            ["href": "sublink", "templated": false] as JSONValue,
                        ],
                    ],
                ] as [String: JSONValue]
        )
    }

    @Test func linkWithRelInReadingOrder() {
        #expect(
            makeManifest(readingOrder: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1"),
            ]).linkWithRel("rel1")?.href == "l2"
        )
    }

    @Test func linkWithRelInLinks() {
        #expect(
            makeManifest(links: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1"),
            ]).linkWithRel("rel1")?.href == "l2"
        )
    }

    @Test func linkWithRelInResources() {
        #expect(
            makeManifest(resources: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1"),
            ]).linkWithRel("rel1")?.href == "l2"
        )
    }

    @Test func linksWithRel() {
        #expect(
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
            ).linksWithRel("rel1") ==
                [
                    Link(href: "l4", rel: "rel1"),
                    Link(href: "l6", rel: "rel1"),
                    Link(href: "l2", rel: "rel1"),
                ]
        )
    }

    @Test func linksWithRelEmpty() {
        #expect(
            makeManifest(resources: [
                Link(href: "l1"),
                Link(href: "l2"),
            ]).linksWithRel("rel1") == []
        )
    }

    struct LocatorForLink {
        @Test func minimalLink() {
            let sut = makeManifest(readingOrder: [
                Link(href: "/href", mediaType: .html, title: "Resource"),
            ])

            #expect(
                sut.locator(for: Link(href: "/href")) ==
                    Locator(href: "/href", mediaType: .html, title: "Resource", locations: Locator.Locations(progression: 0.0))
            )
        }

        @Test func linkInReadingOrderResourcesOrLinks() {
            let sut = makeManifest(
                links: [Link(href: "/href3", mediaType: .html)],
                readingOrder: [Link(href: "/href1", mediaType: .html)],
                resources: [Link(href: "/href2", mediaType: .html)]
            )

            #expect(
                sut.locator(for: Link(href: "/href1")) ==
                    Locator(href: "/href1", mediaType: .html, locations: Locator.Locations(progression: 0.0))
            )
            #expect(
                sut.locator(for: Link(href: "/href2")) ==
                    Locator(href: "/href2", mediaType: .html, locations: Locator.Locations(progression: 0.0))
            )
            #expect(
                sut.locator(for: Link(href: "/href3")) ==
                    Locator(href: "/href3", mediaType: .html, locations: Locator.Locations(progression: 0.0))
            )
        }

        @Test func linkWithFragment() throws {
            let sut = makeManifest(readingOrder: [
                Link(href: "/href", mediaType: .html, title: "Resource"),
            ])

            #expect(
                try sut.locator(for: Link(href: "/href#page=42", mediaType: #require(MediaType("text/xml")), title: "My link")) ==
                    Locator(href: "/href", mediaType: .html, title: "Resource", locations: Locator.Locations(fragments: ["page=42"]))
            )
        }

        /// The link's title is used when the resource itself has none.
        @Test func fallsBackOnLinkTitle() {
            let sut = makeManifest(readingOrder: [
                Link(href: "/href", mediaType: .html),
            ])

            #expect(
                sut.locator(for: Link(href: "/href", title: "My link")) ==
                    Locator(href: "/href", mediaType: .html, title: "My link", locations: Locator.Locations(progression: 0.0))
            )
        }

        @Test func unknownLink() {
            let sut = makeManifest(readingOrder: [
                Link(href: "/href", mediaType: .html),
            ])

            #expect(sut.locator(for: Link(href: "notfound")) == nil)
        }
    }
}

// MARK: - Helpers

private func makeManifest(metadata: Metadata = Metadata(title: ""), links: [Link] = [], readingOrder: [Link] = [], resources: [Link] = []) -> Manifest {
    Manifest(metadata: metadata, links: links, readingOrder: readingOrder, resources: resources)
}
