//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

struct PublicationTests {
    @Test func getJSON() {
        #expect(
            Publication(
                manifest: Manifest(
                    metadata: Metadata(title: "Title"),
                    links: [Link(href: "manifest.json", rels: [.self])],
                    readingOrder: [Link(href: "chap1.html", mediaType: .html)]
                )
            ).jsonManifest ==
                (try? [String: JSONValue]([
                    "metadata": ["title": "Title", "readingProgression": "auto"],
                    "links": [
                        ["href": "manifest.json", "rel": ["self"], "templated": false],
                    ],
                    "readingOrder": [
                        ["href": "chap1.html", "type": "text/html", "templated": false],
                    ],
                ]).jsonString())
        )
    }

    @Test func conformsToProfile() {
        func makePub(_ readingOrder: [Link], conformsTo: [Publication.Profile] = []) -> Publication {
            Publication(manifest: Manifest(
                metadata: Metadata(conformsTo: conformsTo),
                readingOrder: readingOrder
            ))
        }

        // An empty reading order doesn't conform to anything.
        #expect(!makePub([], conformsTo: [.epub]).conforms(to: .epub))

        #expect(makePub([Link(href: "c1.mp3", mediaType: .mp3), Link(href: "c2.aac", mediaType: .aac)]).conforms(to: .audiobook))
        #expect(makePub([Link(href: "c1.jpg", mediaType: .jpeg), Link(href: "c2.png", mediaType: .png)]).conforms(to: .divina))
        #expect(makePub([Link(href: "c1.pdf", mediaType: .pdf), Link(href: "c2.pdf", mediaType: .pdf)]).conforms(to: .pdf))

        // Mixed media types disable implicit conformance.
        #expect(!makePub([Link(href: "c1.mp3", mediaType: .mp3), Link(href: "c2.jpg", mediaType: .jpeg)]).conforms(to: .audiobook))
        #expect(!makePub([Link(href: "c1.mp3", mediaType: .mp3), Link(href: "c2.jpg", mediaType: .jpeg)]).conforms(to: .divina))

        // XHTML could be EPUB or a Web Publication, so we require an explicit EPUB profile.
        #expect(!makePub([Link(href: "c1.xhtml", mediaType: .xhtml), Link(href: "c2.xhtml", mediaType: .xhtml)]).conforms(to: .epub))
        #expect(!makePub([Link(href: "c1.html", mediaType: .html), Link(href: "c2.html", mediaType: .html)]).conforms(to: .epub))
        #expect(makePub([Link(href: "c1.xhtml", mediaType: .xhtml), Link(href: "c2.xhtml", mediaType: .xhtml)], conformsTo: [.epub]).conforms(to: .epub))
        #expect(makePub([Link(href: "c1.html", mediaType: .html), Link(href: "c2.html", mediaType: .html)], conformsTo: [.epub]).conforms(to: .epub))

        // Implicit conformance always take precedence over explicit profiles.
        #expect(makePub([Link(href: "c1.mp3", mediaType: .mp3), Link(href: "c2.aac", mediaType: .aac)]).conforms(to: .audiobook))
        #expect(makePub([Link(href: "c1.mp3", mediaType: .mp3), Link(href: "c2.aac", mediaType: .aac)], conformsTo: [.divina]).conforms(to: .audiobook))
        #expect(!makePub([Link(href: "c1.mp3", mediaType: .mp3), Link(href: "c2.aac", mediaType: .aac)], conformsTo: [.divina]).conforms(to: .divina))

        // Unknown profile
        let profile = Publication.Profile("http://extension")
        #expect(!makePub([Link(href: "file", mediaType: .text)]).conforms(to: profile))
        #expect(makePub([Link(href: "file", mediaType: .text)], conformsTo: [profile]).conforms(to: profile))
    }

    /// `Publication.get()` delegates to the `Container`.
    @Test func getDelegatesToContainer() async throws {
        let link = Link(href: "test", mediaType: .html)
        let publication = makePublication(
            links: [link],
            container: SingleResourceContainer(resource: DataResource(string: "hello"), at: link.url())
        )

        let result = try await publication.get(link)?.read().asString().get()
        #expect(result == "hello")
    }

    struct BaseURL {
        @Test func fromSelfLink() {
            #expect(
                makePublication(links: [
                    Link(href: "http://host/folder/manifest.json", rel: .self),
                ]).baseURL?.string == "http://host/folder/"
            )
        }

        @Test func missingWithoutSelfLink() {
            #expect(
                makePublication(links: [
                    Link(href: "http://host/folder/manifest.json"),
                ]).baseURL == nil
            )
        }

        @Test func atRoot() {
            #expect(
                makePublication(links: [
                    Link(href: "http://host/manifest.json", rel: .self),
                ]).baseURL?.string == "http://host/"
            )
        }
    }

    struct LinkWithHREF {
        @Test func inReadingOrder() {
            #expect(
                makePublication(readingOrder: [
                    Link(href: "l1"),
                    Link(href: "l2"),
                ]).linkWithHREF(AnyURL(string: "l2")!)?.href == "l2"
            )
        }

        @Test func inLinks() {
            #expect(
                makePublication(links: [
                    Link(href: "l1"),
                    Link(href: "l2"),
                ]).linkWithHREF(AnyURL(string: "l2")!)?.href == "l2"
            )
        }

        @Test func inResources() {
            #expect(
                makePublication(resources: [
                    Link(href: "l1"),
                    Link(href: "l2"),
                ]).linkWithHREF(AnyURL(string: "l2")!)?.href == "l2"
            )
        }

        @Test func inAlternate() {
            #expect(
                makePublication(resources: [
                    Link(href: "l1", alternates: [
                        Link(href: "l2", alternates: [
                            Link(href: "l3"),
                        ]),
                    ]),
                ]).linkWithHREF(AnyURL(string: "l3")!)?.href == "l3"
            )
        }

        @Test func inChildren() {
            #expect(
                makePublication(resources: [
                    Link(href: "l1", children: [
                        Link(href: "l2", children: [
                            Link(href: "l3"),
                        ]),
                    ]),
                ]).linkWithHREF(AnyURL(string: "l3")!)?.href == "l3"
            )
        }

        @Test func ignoresQuery() {
            let publication = makePublication(links: [
                Link(href: "l1?q=a"),
                Link(href: "l2"),
            ])

            #expect(publication.linkWithHREF(AnyURL(string: "l1?q=a")!)?.href == "l1?q=a")
            #expect(publication.linkWithHREF(AnyURL(string: "l2?q=b")!)?.href == "l2")
        }

        @Test func ignoresAnchor() {
            let publication = makePublication(links: [
                Link(href: "l1#a"),
                Link(href: "l2"),
            ])

            #expect(publication.linkWithHREF(AnyURL(string: "l1#a")!)?.href == "l1#a")
            #expect(publication.linkWithHREF(AnyURL(string: "l2#b")!)?.href == "l2")
        }
    }

    struct LinkWithRel {
        @Test func inReadingOrder() {
            #expect(
                makePublication(readingOrder: [
                    Link(href: "l1"),
                    Link(href: "l2", rel: "rel1"),
                ]).linkWithRel("rel1")?.href == "l2"
            )
        }

        @Test func inLinks() {
            #expect(
                makePublication(links: [
                    Link(href: "l1"),
                    Link(href: "l2", rel: "rel1"),
                ]).linkWithRel("rel1")?.href == "l2"
            )
        }

        @Test func inResources() {
            #expect(
                makePublication(resources: [
                    Link(href: "l1"),
                    Link(href: "l2", rel: "rel1"),
                ]).linkWithRel("rel1")?.href == "l2"
            )
        }

        @Test func allMatchingLinks() {
            #expect(
                makePublication(
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

        @Test func noMatchingLinks() {
            #expect(
                makePublication(resources: [
                    Link(href: "l1"),
                    Link(href: "l2"),
                ]).linksWithRel("rel1") == []
            )
        }
    }

    struct LocatorForLink {
        /// `Publication` forwards to its manifest.
        @Test func forwardsToManifest() {
            let sut = makePublication(readingOrder: [
                Link(href: "/href", mediaType: .html, title: "Resource"),
            ])

            #expect(
                sut.locator(for: Link(href: "/href")) ==
                    Locator(href: "/href", mediaType: .html, title: "Resource", locations: Locator.Locations(progression: 0.0))
            )
        }

        @Test func unknownLink() {
            let sut = makePublication(readingOrder: [
                Link(href: "/href", mediaType: .html),
            ])

            #expect(sut.locator(for: Link(href: "notfound")) == nil)
        }
    }

    struct NormalizeLocator {
        @Test func remotePublication() {
            let publication = Publication(
                manifest: Manifest(
                    links: [Link(href: "https://example.com/foo/manifest.json", rels: [.self])],
                    readingOrder: [
                        Link(href: "chap1.html", mediaType: .html),
                        Link(href: "bar/c'est%20valide.html", mediaType: .html),
                    ]
                )
            )

            // Passthrough for invalid locators.
            #expect(
                publication.normalizeLocator(
                    Locator(href: "invalid", mediaType: .html)
                ) == Locator(href: "invalid", mediaType: .html)
            )

            // Absolute URLs relative to self are made relative.
            #expect(
                publication.normalizeLocator(
                    Locator(href: "https://example.com/foo/chap1.html", mediaType: .html)
                ) == Locator(href: "chap1.html", mediaType: .html)
            )
            #expect(
                publication.normalizeLocator(
                    Locator(href: "https://other.com/chap1.html", mediaType: .html)
                ) == Locator(href: "https://other.com/chap1.html", mediaType: .html)
            )
        }

        @Test func packagedPublication() {
            let publication = Publication(
                manifest: Manifest(
                    readingOrder: [
                        Link(href: "foo/chap1.html", mediaType: .html),
                        Link(href: "bar/c'est%20valide.html", mediaType: .html),
                    ]
                )
            )

            // Passthrough for invalid locators.
            #expect(
                publication.normalizeLocator(
                    Locator(href: "invalid", mediaType: .html)
                ) == Locator(href: "invalid", mediaType: .html)
            )

            // Leading slashes are removed
            #expect(
                publication.normalizeLocator(
                    Locator(href: "foo/chap1.html", mediaType: .html)
                ) == Locator(href: "foo/chap1.html", mediaType: .html)
            )
        }
    }
}

// MARK: - Helpers

private func makePublication(
    metadata: Metadata = Metadata(title: ""),
    links: [Link] = [],
    readingOrder: [Link] = [],
    resources: [Link] = [],
    container: Container? = nil,
    services: PublicationServicesBuilder = PublicationServicesBuilder()
) -> Publication {
    Publication(
        manifest: Manifest(
            metadata: metadata,
            links: links,
            readingOrder: readingOrder,
            resources: resources
        ),
        container: container ?? EmptyContainer(),
        servicesBuilder: services
    )
}
