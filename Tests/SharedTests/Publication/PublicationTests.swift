//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

class PublicationTests: XCTestCase {
    func testGetJSON() {
        XCTAssertEqual(
            Publication(
                manifest: Manifest(
                    metadata: Metadata(title: "Title"),
                    links: [Link(href: "/manifest.json", rels: [.`self`])],
                    readingOrder: [Link(href: "/chap1.html", type: "text/html")]
                )
            ).jsonManifest,
            serializeJSONString([
                "metadata": ["title": "Title", "readingProgression": "auto"],
                "links": [
                    ["href": "/manifest.json", "rel": ["self"], "templated": false] as [String: Any],
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html", "templated": false] as [String: Any],
                ],
            ] as [String: Any])
        )
    }

    func testConformsToProfile() {
        func makePub(_ readingOrder: [String], conformsTo: [Publication.Profile] = []) -> Publication {
            Publication(manifest: Manifest(
                metadata: Metadata(
                    conformsTo: conformsTo,
                    title: ""
                ),
                readingOrder: readingOrder.map { Link(href: $0) }
            ))
        }

        // An empty reading order doesn't conform to anything.
        XCTAssertFalse(makePub([], conformsTo: [.epub]).conforms(to: .epub))

        XCTAssertTrue(makePub(["c1.mp3", "c2.aac"]).conforms(to: .audiobook))
        XCTAssertTrue(makePub(["c1.jpg", "c2.png"]).conforms(to: .divina))
        XCTAssertTrue(makePub(["c1.pdf", "c2.pdf"]).conforms(to: .pdf))

        // Mixed media types disable implicit conformance.
        XCTAssertFalse(makePub(["c1.mp3", "c2.jpg"]).conforms(to: .audiobook))
        XCTAssertFalse(makePub(["c1.mp3", "c2.jpg"]).conforms(to: .divina))

        // XHTML could be EPUB or a Web Publication, so we require an explicit EPUB profile.
        XCTAssertFalse(makePub(["c1.xhtml", "c2.xhtml"]).conforms(to: .epub))
        XCTAssertFalse(makePub(["c1.html", "c2.html"]).conforms(to: .epub))
        XCTAssertTrue(makePub(["c1.xhtml", "c2.xhtml"], conformsTo: [.epub]).conforms(to: .epub))
        XCTAssertTrue(makePub(["c1.html", "c2.html"], conformsTo: [.epub]).conforms(to: .epub))

        // Implicit conformance always take precedence over explicit profiles.
        XCTAssertTrue(makePub(["c1.mp3", "c2.aac"]).conforms(to: .audiobook))
        XCTAssertTrue(makePub(["c1.mp3", "c2.aac"], conformsTo: [.divina]).conforms(to: .audiobook))
        XCTAssertFalse(makePub(["c1.mp3", "c2.aac"], conformsTo: [.divina]).conforms(to: .divina))

        // Unknown profile
        let profile = Publication.Profile("http://extension")
        XCTAssertFalse(makePub(["file"]).conforms(to: profile))
        XCTAssertTrue(makePub(["file"], conformsTo: [profile]).conforms(to: profile))
    }

    func testBaseURL() {
        XCTAssertEqual(
            makePublication(links: [
                Link(href: "http://host/folder/manifest.json", rel: .`self`),
            ]).baseURL,
            URL(string: "http://host/folder/")!
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
            ]).baseURL,
            URL(string: "http://host/")!
        )
    }

    func testLinkWithHREFInReadingOrder() {
        XCTAssertEqual(
            makePublication(readingOrder: [
                Link(href: "l1"),
                Link(href: "l2"),
            ]).link(withHREF: "l2")?.href,
            "l2"
        )
    }

    func testLinkWithHREFInLinks() {
        XCTAssertEqual(
            makePublication(links: [
                Link(href: "l1"),
                Link(href: "l2"),
            ]).link(withHREF: "l2")?.href,
            "l2"
        )
    }

    func testLinkWithHREFInResources() {
        XCTAssertEqual(
            makePublication(resources: [
                Link(href: "l1"),
                Link(href: "l2"),
            ]).link(withHREF: "l2")?.href,
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
            ]).link(withHREF: "l3")?.href,
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
            ]).link(withHREF: "l3")?.href,
            "l3"
        )
    }

    func testLinkWithHREFIgnoresQuery() {
        let publication = makePublication(links: [
            Link(href: "l1?q=a"),
            Link(href: "l2"),
        ])

        XCTAssertEqual(publication.link(withHREF: "l1?q=a")?.href, "l1?q=a")
        XCTAssertEqual(publication.link(withHREF: "l2?q=b")?.href, "l2")
    }

    func testLinkWithHREFIgnoresAnchor() {
        let publication = makePublication(links: [
            Link(href: "l1#a"),
            Link(href: "l2"),
        ])

        XCTAssertEqual(publication.link(withHREF: "l1#a")?.href, "l1#a")
        XCTAssertEqual(publication.link(withHREF: "l2#b")?.href, "l2")
    }

    func testLinkWithRelInReadingOrder() {
        XCTAssertEqual(
            makePublication(readingOrder: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1"),
            ]).link(withRel: "rel1")?.href,
            "l2"
        )
    }

    func testLinkWithRelInLinks() {
        XCTAssertEqual(
            makePublication(links: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1"),
            ]).link(withRel: "rel1")?.href,
            "l2"
        )
    }

    func testLinkWithRelInResources() {
        XCTAssertEqual(
            makePublication(resources: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1"),
            ]).link(withRel: "rel1")?.href,
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
            ).links(withRel: "rel1"),
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
            ]).links(withRel: "rel1"),
            []
        )
    }

    /// `Publication.get()` delegates to the `Fetcher`.
    func testGetDelegatesToFetcher() {
        let link = Link(href: "test", type: "text/html")
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
        let link = Link(href: "test", type: "text/html")
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
        let link = Link(href: "test", type: "text/html", templated: true)
        var requestedLink: Link?
        let publication = makePublication(
            links: [link],
            fetcher: ProxyFetcher {
                requestedLink = $0
                return FailureResource(link: $0, error: .notFound(nil))
            }
        )

        _ = publication.get("test?query=param")

        XCTAssertEqual(requestedLink, Link(href: "test?query=param", type: "text/html", templated: false))
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
