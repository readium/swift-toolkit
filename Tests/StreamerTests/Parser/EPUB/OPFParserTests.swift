//
//  Copyright 2025 Readium Foundation. All rights reserved.
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
                link(id: "titlepage", href: "EPUB/titlepage.xhtml"),
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
            link(id: "titlepage", href: "titlepage.xhtml", mediaType: .xhtml),
            link(id: "chapter01", href: "EPUB/chapter01.xhtml", mediaType: .xhtml),
        ])
        XCTAssertEqual(sut.resources, [
            link(id: "font0", href: "EPUB/fonts/MinionPro.otf", mediaType: MediaType("application/vnd.ms-opentype")!),
            link(id: "nav", href: "EPUB/nav.xhtml", mediaType: .xhtml, rels: [.contents]),
            link(id: "css", href: "style.css", mediaType: .css),
            link(id: "chapter02", href: "EPUB/chapter02.xhtml", mediaType: .xhtml),
            link(id: "chapter01_smil", href: "EPUB/chapter01.smil", mediaType: .smil),
            link(id: "chapter02_smil", href: "EPUB/chapter02.smil", mediaType: .smil),
            link(id: "img01a", href: "EPUB/images/alice01a.png", mediaType: .png, rels: [.cover]),
            link(id: "img02a", href: "EPUB/images/alice02a.gif", mediaType: .gif),
            link(id: "nomediatype", href: "EPUB/nomediatype.txt"),
        ])
    }

    func testParseLinksFromSpine() throws {
        let sut = try parseManifest("links-spine", at: "EPUB/content.opf").manifest

        XCTAssertEqual(sut.readingOrder, [
            link(id: "titlepage", href: "EPUB/titlepage.xhtml"),
        ])
    }

    func testParseLinkProperties() throws {
        let sut = try parseManifest("links-properties", at: "EPUB/content.opf").manifest

        XCTAssertEqual(sut.readingOrder.count, 8)
        XCTAssertEqual(sut.readingOrder[0], link(id: "chapter01", href: "EPUB/chapter01.xhtml", rels: [.contents], properties: Properties([
            "contains": ["mathml"],
            "page": "right",
        ])))
        XCTAssertEqual(sut.readingOrder[1], link(id: "chapter02", href: "EPUB/chapter02.xhtml", properties: Properties([
            "contains": ["remote-resources"],
            "page": "left",
        ])))
        XCTAssertEqual(sut.readingOrder[2], link(id: "chapter03", href: "EPUB/chapter03.xhtml", properties: Properties([
            "contains": ["js", "svg"],
            "page": "center",
        ])))
        XCTAssertEqual(sut.readingOrder[3], link(id: "chapter04", href: "EPUB/chapter04.xhtml", properties: Properties([
            "contains": ["onix", "xmp"],
        ])))
        XCTAssertEqual(sut.readingOrder[4], link(id: "chapter05", href: "EPUB/chapter05.xhtml", properties: Properties()))
        XCTAssertEqual(sut.readingOrder[5], link(id: "chapter06", href: "EPUB/chapter06.xhtml", properties: Properties()))
        XCTAssertEqual(sut.readingOrder[6], link(id: "chapter07", href: "EPUB/chapter07.xhtml", properties: Properties()))
        XCTAssertEqual(sut.readingOrder[7], link(id: "chapter08", href: "EPUB/chapter08.xhtml", properties: Properties()))
    }

    func testParseEPUB2Cover() throws {
        let sut = try parseManifest("cover-epub2", at: "EPUB/content.opf").manifest

        XCTAssertEqual(sut.resources, [
            link(id: "my-cover", href: "EPUB/cover.jpg", mediaType: .jpeg, rels: [.cover]),
        ])
    }

    func testParseEPUB3Cover() throws {
        let sut = try parseManifest("cover-epub3", at: "EPUB/content.opf").manifest

        XCTAssertEqual(sut.resources, [
            link(id: "my-cover", href: "EPUB/cover.jpg", mediaType: .jpeg, rels: [.cover]),
        ])
    }

    // MARK: - Toolkit

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

    func link(id: String? = nil, href: String, mediaType: MediaType? = nil, templated: Bool = false, title: String? = nil, rels: [LinkRelation] = [], properties: Properties = .init(), children: [Link] = []) -> Link {
        var properties = properties.otherProperties
        if let id = id {
            properties["id"] = id
        }
        return Link(href: href, mediaType: mediaType, templated: templated, title: title, rels: rels, properties: Properties(properties), children: children)
    }
}
