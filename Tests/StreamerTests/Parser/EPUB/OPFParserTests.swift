//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class OPFParserTests: XCTestCase {
    let fixtures = Fixtures(path: "OPF")

    func testParseMinimalOPF() throws {
        let sut = try parseManifest("minimal", at: "EPUB/content.opf")

        XCTAssertEqual(sut.manifest, Manifest(
            metadata: Metadata(
                conformsTo: [.epub],
                title: "Alice's Adventures in Wonderland",
                layout: .reflowable
            ),
            readingOrder: [
                link(href: "EPUB/titlepage.xhtml"),
            ]
        ))
    }

    func testParseEPUB2Version() throws {
        let sut = try parseManifest("version-epub2")
        XCTAssertEqual(sut.version, "2.0.1")
    }

    func testParseEPUB3Version() throws {
        let sut = try parseManifest("version-epub3")
        XCTAssertEqual(sut.version, "3.0")
    }

    func testParseDefaultEPUBVersion() throws {
        let sut = try parseManifest("version-default")
        XCTAssertEqual(sut.version, "1.2")
    }

    func testParseLinks() throws {
        let sut = try parseManifest("links", at: "EPUB/content.opf").manifest

        XCTAssertEqual(sut.links, [])
        XCTAssertEqual(sut.readingOrder, [
            link(href: "titlepage.xhtml", mediaType: .xhtml),
            link(href: "EPUB/chapter01.xhtml", mediaType: .xhtml),
        ])
        XCTAssertEqual(sut.resources, [
            link(href: "EPUB/fonts/MinionPro.otf", mediaType: MediaType("application/vnd.ms-opentype")!),
            link(href: "EPUB/nav.xhtml", mediaType: .xhtml, rels: [.contents]),
            link(href: "style.css", mediaType: .css),
            link(href: "EPUB/chapter02.xhtml", mediaType: .xhtml),
            link(href: "EPUB/chapter01.smil", mediaType: .smil),
            link(href: "EPUB/chapter02.smil", mediaType: .smil),
            link(href: "EPUB/images/alice01a.png", mediaType: .png, rels: [.cover]),
            link(href: "EPUB/images/alice02a.gif", mediaType: .gif),
            link(href: "EPUB/nomediatype.txt"),
        ])
    }

    func testParseLinksFromSpine() throws {
        let sut = try parseManifest("links-spine", at: "EPUB/content.opf").manifest

        XCTAssertEqual(sut.readingOrder, [
            link(href: "EPUB/titlepage.xhtml"),
        ])
    }

    func testParseLinkProperties() throws {
        let sut = try parseManifest("links-properties", at: "EPUB/content.opf").manifest

        XCTAssertEqual(sut.readingOrder.count, 8)
        XCTAssertEqual(sut.readingOrder[0], link(href: "EPUB/chapter01.xhtml", rels: [.contents], properties: Properties([
            "contains": ["mathml"],
            "page": "right",
        ])))
        XCTAssertEqual(sut.readingOrder[1], link(href: "EPUB/chapter02.xhtml", properties: Properties([
            "contains": ["remote-resources"],
            "page": "left",
        ])))
        XCTAssertEqual(sut.readingOrder[2], link(href: "EPUB/chapter03.xhtml", properties: Properties([
            "contains": ["js", "svg"],
            "page": "center",
        ])))
        XCTAssertEqual(sut.readingOrder[3], link(href: "EPUB/chapter04.xhtml", properties: Properties([
            "contains": ["onix", "xmp"],
        ])))
        XCTAssertEqual(sut.readingOrder[4], link(href: "EPUB/chapter05.xhtml"))
        XCTAssertEqual(sut.readingOrder[5], link(href: "EPUB/chapter06.xhtml"))
        XCTAssertEqual(sut.readingOrder[6], link(href: "EPUB/chapter07.xhtml"))
        XCTAssertEqual(sut.readingOrder[7], link(href: "EPUB/chapter08.xhtml"))
    }

    func testParseEPUB2Cover() throws {
        let sut = try parseManifest("cover-epub2", at: "EPUB/content.opf").manifest

        XCTAssertEqual(sut.resources, [
            link(href: "EPUB/cover.jpg", mediaType: .jpeg, rels: [.cover]),
        ])
    }

    func testParseEPUB3Cover() throws {
        let sut = try parseManifest("cover-epub3", at: "EPUB/content.opf").manifest

        XCTAssertEqual(sut.resources, [
            link(href: "EPUB/cover.jpg", mediaType: .jpeg, rels: [.cover]),
        ])
    }

    // MARK: - Fallback Handling

    /// When an image is in the spine with an HTML fallback, the image should be
    /// in readingOrder and HTML should be added as an alternate.
    func testParseImageInSpineWithHTMLFallback() throws {
        let sut = try parseManifest("fallback-image-in-spine", at: "EPUB/content.opf").manifest

        XCTAssertEqual(sut.readingOrder.count, 2)

        // First image in spine
        XCTAssertEqual(sut.readingOrder[0].href, "EPUB/page1.jpg")
        XCTAssertEqual(sut.readingOrder[0].mediaType, .jpeg)
        XCTAssertEqual(sut.readingOrder[0].alternates, [
            Link(href: "EPUB/page1.xhtml", mediaType: .xhtml),
        ])

        // Second image in spine
        XCTAssertEqual(sut.readingOrder[1].href, "EPUB/page2.png")
        XCTAssertEqual(sut.readingOrder[1].mediaType, .png)
        XCTAssertEqual(sut.readingOrder[1].alternates, [
            Link(href: "EPUB/page2.xhtml", mediaType: .xhtml),
        ])

        // HTML fallbacks should not be in resources
        XCTAssertTrue(sut.resources.isEmpty)
    }

    /// When HTML is in the spine with an image fallback, we swap: the image
    /// should be in readingOrder and HTML should be added as an alternate.
    func testParseHTMLInSpineWithImageFallback() throws {
        let sut = try parseManifest("fallback-html-in-spine", at: "EPUB/content.opf").manifest

        XCTAssertEqual(sut.readingOrder.count, 2)

        // First item: image swapped into readingOrder, HTML as alternate
        XCTAssertEqual(sut.readingOrder[0].href, "EPUB/page1.jpg")
        XCTAssertEqual(sut.readingOrder[0].mediaType, .jpeg)
        XCTAssertEqual(sut.readingOrder[0].alternates, [
            Link(href: "EPUB/page1.xhtml", mediaType: .xhtml),
        ])

        // Second item: image swapped into readingOrder, HTML as alternate
        XCTAssertEqual(sut.readingOrder[1].href, "EPUB/page2.png")
        XCTAssertEqual(sut.readingOrder[1].mediaType, .png)
        XCTAssertEqual(sut.readingOrder[1].alternates, [
            Link(href: "EPUB/page2.xhtml", mediaType: .xhtml),
        ])

        // Fallback images should not be in resources
        XCTAssertTrue(sut.resources.isEmpty)
    }

    /// General fallback handling: any fallback should be translated to an
    /// alternate.
    func testParseGeneralFallbackAsAlternate() throws {
        let sut = try parseManifest("fallback-general", at: "EPUB/content.opf").manifest

        XCTAssertEqual(sut.readingOrder.count, 2)

        // First item: XHTML with XHTML fallback
        XCTAssertEqual(sut.readingOrder[0].href, "EPUB/chapter1.xhtml")
        XCTAssertEqual(sut.readingOrder[0].mediaType, .xhtml)
        XCTAssertEqual(sut.readingOrder[0].alternates, [
            Link(href: "EPUB/chapter1-alt.xhtml", mediaType: .xhtml),
        ])

        // Second item: XHTML with PDF fallback
        XCTAssertEqual(sut.readingOrder[1].href, "EPUB/chapter2.xhtml")
        XCTAssertEqual(sut.readingOrder[1].mediaType, .xhtml)
        XCTAssertEqual(sut.readingOrder[1].alternates, [
            Link(href: "EPUB/chapter2.pdf", mediaType: .pdf),
        ])

        // Fallback resources should not be in resources
        XCTAssertTrue(sut.resources.isEmpty)
    }

    // MARK: - Divina Inference

    /// When all spine items are bitmaps, the metadata should have:
    /// - `layout = .fixed` to use the FXL navigator
    /// - `.divina` added to `conformsTo`
    func testParseAllImagesInSpineSetsFixedLayoutAndDivinaProfile() throws {
        let sut = try parseManifest("all-images-in-spine", at: "EPUB/content.opf").manifest

        // Should have fixed layout
        XCTAssertEqual(sut.metadata.layout, .fixed)

        // Should conform to both EPUB and Divina
        XCTAssertTrue(sut.metadata.conformsTo.contains(.epub))
        XCTAssertTrue(sut.metadata.conformsTo.contains(.divina))

        // Reading order should contain all images
        XCTAssertEqual(sut.readingOrder.count, 3)
        XCTAssertEqual(sut.readingOrder[0].mediaType, .jpeg)
        XCTAssertEqual(sut.readingOrder[1].mediaType, .png)
        XCTAssertEqual(sut.readingOrder[2].mediaType, .gif)
    }

    /// When not all spine items are bitmaps, the metadata should NOT have
    /// `.divina` profile and layout should remain reflowable.
    func testParseMixedSpineDoesNotSetDivinaProfile() throws {
        let sut = try parseManifest("fallback-image-html-mixed", at: "EPUB/content.opf").manifest

        // Should have reflowable layout (default)
        XCTAssertEqual(sut.metadata.layout, .reflowable)

        // Should only conform to EPUB, not Divina
        XCTAssertTrue(sut.metadata.conformsTo.contains(.epub))
        XCTAssertFalse(sut.metadata.conformsTo.contains(.divina))
    }

    // MARK: - Helpers

    func parseManifest(_ name: String, at path: String = "EPUB/content.opf", displayOptions: String? = nil) throws -> (manifest: Manifest, version: String) {
        let parts = try OPFParser(
            baseURL: XCTUnwrap(RelativeURL(path: path)),
            data: fixtures.data(at: "\(name).opf"),
            displayOptionsData: displayOptions.map { fixtures.data(at: "\($0).xml") },
            encryptions: [:]
        ).parsePublication()

        return (Manifest(
            metadata: parts.metadata,
            readingOrder: parts.readingOrder,
            resources: parts.resources
        ), parts.version)
    }

    func link(href: String, mediaType: MediaType? = nil, templated: Bool = false, title: String? = nil, rels: [LinkRelation] = [], properties: Properties = .init(), children: [Link] = []) -> Link {
        Link(href: href, mediaType: mediaType, templated: templated, title: title, rels: rels, properties: properties, children: children)
    }
}
