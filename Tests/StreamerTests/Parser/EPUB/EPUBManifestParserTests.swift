//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class EPUBManifestParserTests: XCTestCase {
    let fixtures = Fixtures()

    func testParseFullManifest() async throws {
        let sut = EPUBManifestParser(
            container: CompositeContainer(
                FileContainer(files: [
                    RelativeURL(path: "META-INF/container.xml")!: fixtures.url(for: "Container/container.xml"),
                    RelativeURL(path: "EPUB/content.opf")!: fixtures.url(for: "OPF/full-metadata.opf")
                ]),
            ),
            encryptions: [:]
        )
        
        let manifest = try await sut.parseManifest()
        
        XCTAssertEqual(
            manifest,
            Manifest(
                metadata: Metadata(
                    identifier: "urn:uuid:7408D53A-5383-40AA-8078-5256C872AE41",
                    conformsTo: [.epub],
                    title: "Alice's Adventures in Wonderland",
                    subtitle: "Alice returns to the magical world from her childhood adventure",
                    accessibility: Accessibility(
                        certification: Accessibility.Certification(
                            certifiedBy: "EDRLab"
                        )
                    ),
                    modified: "2012-04-02T12:47:00Z".dateFromISO8601,
                    published: "1865-07-04".dateFromISO8601,
                    languages: ["en-GB", "en"],
                    subjects: [
                        Subject(name: "fiction"),
                        Subject(name: "classic", scheme: "thema", code: "DCA"),
                    ],
                    authors: [Contributor(name: "Lewis Carroll")],
                    publishers: [Contributor(name: "D. Appleton and Co")],
                    readingProgression: .rtl,
                    description: "The book description.",
                    numberOfPages: 42,
                    otherMetadata: [
                        "http://purl.org/dc/terms/source": [
                            "Feedbooks",
                            [
                                "@value": "Web",
                                "http://my.url/#scheme": "http",
                            ],
                            "Internet",
                        ] as [Any],
                        "http://purl.org/dc/terms/rights": "Public Domain",
                        "http://idpf.org/epub/vocab/package/#type": "article",
                        "http://my.url/#customProperty": [
                            "@value": "Custom property",
                            "http://my.url/#refine1": "Refine 1",
                            "http://my.url/#refine2": "Refine 2",
                        ],
                        "http://purl.org/dc/terms/format": "application/epub+zip",
                        "presentation": [
                            "continuous": false,
                            "spread": "both",
                            "overflow": "scrolled",
                            "orientation": "landscape",
                            "layout": "fixed",
                        ] as [String: Any],
                    ]
                ),
                readingOrder: [
                    link(id: "titlepage", href: "EPUB/titlepage.xhtml", mediaType: .xhtml),
                    link(id: "chapter01", href: "EPUB/chapter01.xhtml", mediaType: .xhtml),
                ],
                resources: [
                    link(id: "font0", href: "EPUB/fonts/MinionPro.otf", mediaType: MediaType("application/vnd.ms-opentype")!),
                    link(id: "nav", href: "EPUB/nav.xhtml", mediaType: .xhtml, rels: [.contents]),
                    link(id: "css", href: "EPUB/style.css", mediaType: .css),
                    link(id: "img01a", href: "EPUB/images/alice01a.gif", mediaType: .gif, rels: [.cover]),
                    link(id: "img02a", href: "EPUB/images/alice02a.gif", mediaType: .gif),
                ]
            )
        )
    }
    
    private func link(
        id: String? = nil,
        href: String,
        mediaType: MediaType? = nil,
        templated: Bool = false,
        title: String? = nil,
        rels: [LinkRelation] = [],
        properties: Properties = .init(),
        children: [Link] = []
    ) -> Link {
        var properties = properties.otherProperties
        if let id = id {
            properties["id"] = id
        }
        return Link(href: href, mediaType: mediaType, templated: templated, title: title, rels: rels, properties: Properties(properties), children: children)
    }
}

