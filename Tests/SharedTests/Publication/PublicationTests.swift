//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class PublicationTests: XCTestCase {
    func testGetJSON() {
        XCTAssertEqual(
            Publication(
                manifest: Manifest(
                    metadata: Metadata(title: "Title"),
                    links: [Link(href: "manifest.json", rels: [.`self`])],
                    readingOrder: [Link(href: "chap1.html", mediaType: .html)]
                )
            ).jsonManifest,
            serializeJSONString([
                "metadata": ["title": "Title", "readingProgression": "auto"],
                "links": [
                    ["href": "manifest.json", "rel": ["self"], "templated": false] as [String: Any],
                ],
                "readingOrder": [
                    ["href": "chap1.html", "type": "text/html", "templated": false] as [String: Any],
                ],
            ] as [String: Any])
        )
    }

    func testConformsToProfile() {
        func makePub(_ readingOrder: [Link], conformsTo: [Publication.Profile] = []) -> Publication {
            Publication(manifest: Manifest(
                metadata: Metadata(conformsTo: conformsTo),
                readingOrder: readingOrder
            ))
        }

        // An empty reading order doesn't conform to anything.
        XCTAssertFalse(makePub([], conformsTo: [.epub]).conforms(to: .epub))

        XCTAssertTrue(makePub([Link(href: "c1.mp3", mediaType: .mp3), Link(href: "c2.aac", mediaType: .aac)]).conforms(to: .audiobook))
        XCTAssertTrue(makePub([Link(href: "c1.jpg", mediaType: .jpeg), Link(href: "c2.png", mediaType: .png)]).conforms(to: .divina))
        XCTAssertTrue(makePub([Link(href: "c1.pdf", mediaType: .pdf), Link(href: "c2.pdf", mediaType: .pdf)]).conforms(to: .pdf))

        // Mixed media types disable implicit conformance.
        XCTAssertFalse(makePub([Link(href: "c1.mp3", mediaType: .mp3), Link(href: "c2.jpg", mediaType: .jpeg)]).conforms(to: .audiobook))
        XCTAssertFalse(makePub([Link(href: "c1.mp3", mediaType: .mp3), Link(href: "c2.jpg", mediaType: .jpeg)]).conforms(to: .divina))

        // XHTML could be EPUB or a Web Publication, so we require an explicit EPUB profile.
        XCTAssertFalse(makePub([Link(href: "c1.xhtml", mediaType: .xhtml), Link(href: "c2.xhtml", mediaType: .xhtml)]).conforms(to: .epub))
        XCTAssertFalse(makePub([Link(href: "c1.html", mediaType: .html), Link(href: "c2.html", mediaType: .html)]).conforms(to: .epub))
        XCTAssertTrue(makePub([Link(href: "c1.xhtml", mediaType: .xhtml), Link(href: "c2.xhtml", mediaType: .xhtml)], conformsTo: [.epub]).conforms(to: .epub))
        XCTAssertTrue(makePub([Link(href: "c1.html", mediaType: .html), Link(href: "c2.html", mediaType: .html)], conformsTo: [.epub]).conforms(to: .epub))

        // Implicit conformance always take precedence over explicit profiles.
        XCTAssertTrue(makePub([Link(href: "c1.mp3", mediaType: .mp3), Link(href: "c2.aac", mediaType: .aac)]).conforms(to: .audiobook))
        XCTAssertTrue(makePub([Link(href: "c1.mp3", mediaType: .mp3), Link(href: "c2.aac", mediaType: .aac)], conformsTo: [.divina]).conforms(to: .audiobook))
        XCTAssertFalse(makePub([Link(href: "c1.mp3", mediaType: .mp3), Link(href: "c2.aac", mediaType: .aac)], conformsTo: [.divina]).conforms(to: .divina))

        // Unknown profile
        let profile = Publication.Profile("http://extension")
        XCTAssertFalse(makePub([Link(href: "file", mediaType: .text)]).conforms(to: profile))
        XCTAssertTrue(makePub([Link(href: "file", mediaType: .text)], conformsTo: [profile]).conforms(to: profile))
    }

    func testBaseURL() {
        XCTAssertEqual(
            makePublication(links: [
                Link(href: "http://host/folder/manifest.json", rel: .`self`),
            ]).baseURL?.string,
            "http://host/folder/"
        )
    }

    func testBaseURLMissing() {
        XCTAssertNil(
            makePublication(links: [
                Link(href: "http://host/folder/manifest.json"),
            ]).baseURL
        )
    }

    func testBaseURLRoot() {
        XCTAssertEqual(
            makePublication(links: [
                Link(href: "http://host/manifest.json", rel: .`self`),
            ]).baseURL?.string,
            "http://host/"
        )
    }

    func testLinkWithHREFInReadingOrder() {
        XCTAssertEqual(
            makePublication(readingOrder: [
                Link(href: "l1"),
                Link(href: "l2"),
            ]).linkWithHREF(AnyURL(string: "l2")!)?.href,
            "l2"
        )
    }

    func testLinkWithHREFInLinks() {
        XCTAssertEqual(
            makePublication(links: [
                Link(href: "l1"),
                Link(href: "l2"),
            ]).linkWithHREF(AnyURL(string: "l2")!)?.href,
            "l2"
        )
    }

    func testLinkWithHREFInResources() {
        XCTAssertEqual(
            makePublication(resources: [
                Link(href: "l1"),
                Link(href: "l2"),
            ]).linkWithHREF(AnyURL(string: "l2")!)?.href,
            "l2"
        )
    }

    func testLinkWithHREFInAlternate() {
        XCTAssertEqual(
            makePublication(resources: [
                Link(href: "l1", alternates: [
                    Link(href: "l2", alternates: [
                        Link(href: "l3"),
                    ]),
                ]),
            ]).linkWithHREF(AnyURL(string: "l3")!)?.href,
            "l3"
        )
    }

    func testLinkWithHREFInChildren() {
        XCTAssertEqual(
            makePublication(resources: [
                Link(href: "l1", children: [
                    Link(href: "l2", children: [
                        Link(href: "l3"),
                    ]),
                ]),
            ]).linkWithHREF(AnyURL(string: "l3")!)?.href,
            "l3"
        )
    }

    func testLinkWithHREFIgnoresQuery() {
        let publication = makePublication(links: [
            Link(href: "l1?q=a"),
            Link(href: "l2"),
        ])

        XCTAssertEqual(publication.linkWithHREF(AnyURL(string: "l1?q=a")!)?.href, "l1?q=a")
        XCTAssertEqual(publication.linkWithHREF(AnyURL(string: "l2?q=b")!)?.href, "l2")
    }

    func testLinkWithHREFIgnoresAnchor() {
        let publication = makePublication(links: [
            Link(href: "l1#a"),
            Link(href: "l2"),
        ])

        XCTAssertEqual(publication.linkWithHREF(AnyURL(string: "l1#a")!)?.href, "l1#a")
        XCTAssertEqual(publication.linkWithHREF(AnyURL(string: "l2#b")!)?.href, "l2")
    }

    func testLinkWithRelInReadingOrder() {
        XCTAssertEqual(
            makePublication(readingOrder: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1"),
            ]).linkWithRel("rel1")?.href,
            "l2"
        )
    }

    func testLinkWithRelInLinks() {
        XCTAssertEqual(
            makePublication(links: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1"),
            ]).linkWithRel("rel1")?.href,
            "l2"
        )
    }

    func testLinkWithRelInResources() {
        XCTAssertEqual(
            makePublication(resources: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1"),
            ]).linkWithRel("rel1")?.href,
            "l2"
        )
    }

    func testLinksWithRel() {
        XCTAssertEqual(
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
            makePublication(resources: [
                Link(href: "l1"),
                Link(href: "l2"),
            ]).linksWithRel("rel1"),
            []
        )
    }

    /// `Publication.get()` delegates to the `Fetcher`.
    func testGetDelegatesToFetcher() {
        let link = Link(href: "test", mediaType: .html)
        let publication = makePublication(
            links: [link],
            fetcher: ProxyFetcher {
                if link.href == $0.href {
                    return DataResource(link: $0, string: "hello")
                } else {
                    return FailureResource(link: $0, error: .notFound(nil))
                }
            }
        )

        XCTAssertEqual(publication.get(link).readAsString().getOrNil(), "hello")
    }

    /// Services take precedence over the Fetcher in `Publication.get()`.
    func testGetServicesTakePrecedence() {
        let link = Link(href: "test", mediaType: .html)
        let publication = makePublication(
            links: [link],
            fetcher: ProxyFetcher {
                if link.href == $0.href {
                    return DataResource(link: $0, string: "hello")
                } else {
                    return FailureResource(link: $0, error: .notFound(nil))
                }
            },
            services: PublicationServicesBuilder(setup: {
                $0.set(TestService.self) { _ in TestService(link: link) }
            })
        )

        XCTAssertEqual(publication.get(link).readAsString().getOrNil(), "world")
    }

    /// `Publication.get(String)` keeps the query parameters and automatically untemplate the `Link`.
    func testGetKeepsQueryParameters() {
        let link = Link(href: "test", mediaType: .html, templated: true)
        var requestedLink: Link?
        let publication = makePublication(
            links: [link],
            fetcher: ProxyFetcher {
                requestedLink = $0
                return FailureResource(link: $0, error: .notFound(nil))
            }
        )

        _ = publication.get(AnyURL(string: "test?query=param")!)

        XCTAssertEqual(requestedLink, Link(href: "test?query=param", mediaType: .html, templated: false))
    }

    private func makePublication(
        metadata: Metadata = Metadata(title: ""),
        links: [Link] = [],
        readingOrder: [Link] = [],
        resources: [Link] = [],
        fetcher: Fetcher? = nil,
        services: PublicationServicesBuilder = PublicationServicesBuilder()
    ) -> Publication {
        Publication(
            manifest: Manifest(
                metadata: metadata,
                links: links,
                readingOrder: readingOrder,
                resources: resources
            ),
            fetcher: fetcher ?? EmptyFetcher(),
            servicesBuilder: services
        )
    }

    func testNormalizeLocatorRemotePublication() {
        let publication = Publication(
            manifest: Manifest(
                links: [Link(href: "https://example.com/foo/manifest.json", rels: [.`self`])],
                readingOrder: [
                    Link(href: "chap1.html", mediaType: .html),
                    Link(href: "bar/c'est%20valide.html", mediaType: .html),
                ]
            )
        )

        // Passthrough for invalid locators.
        XCTAssertEqual(
            publication.normalizeLocator(
                Locator(href: "invalid", mediaType: .html)
            ),
            Locator(href: "invalid", mediaType: .html)
        )

        // Absolute URLs relative to self are made relative.
        XCTAssertEqual(
            publication.normalizeLocator(
                Locator(href: "https://example.com/foo/chap1.html", mediaType: .html)
            ),
            Locator(href: "chap1.html", mediaType: .html)
        )
        XCTAssertEqual(
            publication.normalizeLocator(
                Locator(href: "https://other.com/chap1.html", mediaType: .html)
            ),
            Locator(href: "https://other.com/chap1.html", mediaType: .html)
        )
    }

    func testNormalizeLocatorPackagedPublication() {
        let publication = Publication(
            manifest: Manifest(
                readingOrder: [
                    Link(href: "foo/chap1.html", mediaType: .html),
                    Link(href: "bar/c'est%20valide.html", mediaType: .html),
                ]
            )
        )

        // Passthrough for invalid locators.
        XCTAssertEqual(
            publication.normalizeLocator(
                Locator(href: "invalid", mediaType: .html)
            ),
            Locator(href: "invalid", mediaType: .html)
        )

        // Leading slashes are removed
        XCTAssertEqual(
            publication.normalizeLocator(
                Locator(href: "foo/chap1.html", mediaType: .html)
            ),
            Locator(href: "foo/chap1.html", mediaType: .html)
        )
    }
}

private struct TestService: PublicationService {
    let link: Link

    lazy var links: [Link] = [link]

    func get(link: Link) -> Resource? {
        if link.href == self.link.href {
            return DataResource(link: link, string: "world")
        } else {
            return FailureResource(link: link, error: .notFound(nil))
        }
    }
}
