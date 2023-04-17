//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import R2Shared
@testable import R2Streamer
import XCTest

class OPFParserTests: XCTestCase {
    let fixtures = Fixtures(path: "OPF")

    func testParseMinimalOPF() throws {
        let sut = try parseManifest("minimal", at: "/EPUB/content.opf")

        XCTAssertEqual(sut.manifest, Manifest(
            metadata: Metadata(
                conformsTo: [.epub],
                title: "Alice's Adventures in Wonderland",
                otherMetadata: [
                    "presentation": [
                        "continuous": false,
                        "spread": "auto",
                        "overflow": "auto",
                        "orientation": "auto",
                        "layout": "reflowable",
                    ] as [String: Any],
                ]
            ),
            readingOrder: [
                link(id: "titlepage", href: "/EPUB/titlepage.xhtml"),
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
        let sut = try parseManifest("links", at: "/EPUB/content.opf").manifest

        XCTAssertEqual(sut.links, [])
        XCTAssertEqual(sut.readingOrder, [
            link(id: "titlepage", href: "/titlepage.xhtml", type: "application/xhtml+xml"),
            link(id: "chapter01", href: "/EPUB/chapter01.xhtml", type: "application/xhtml+xml"),
        ])
        XCTAssertEqual(sut.resources, [
            link(id: "font0", href: "/EPUB/fonts/MinionPro.otf", type: "application/vnd.ms-opentype"),
            link(id: "nav", href: "/EPUB/nav.xhtml", type: "application/xhtml+xml", rels: [.contents]),
            link(id: "css", href: "/style.css", type: "text/css"),
            link(id: "chapter02", href: "/EPUB/chapter02.xhtml", type: "application/xhtml+xml"),
            link(id: "chapter01_smil", href: "/EPUB/chapter01.smil", type: "application/smil+xml"),
            link(id: "chapter02_smil", href: "/EPUB/chapter02.smil", type: "application/smil+xml", duration: 1949),
            link(id: "img01a", href: "/EPUB/images/alice01a.png", type: "image/png", rels: [.cover]),
            link(id: "img02a", href: "/EPUB/images/alice02a.gif", type: "image/gif"),
            link(id: "nomediatype", href: "/EPUB/nomediatype.txt"),
        ])
    }

    func testParseLinksFromSpine() throws {
        let sut = try parseManifest("links-spine", at: "/EPUB/content.opf").manifest

        XCTAssertEqual(sut.readingOrder, [
            link(id: "titlepage", href: "/EPUB/titlepage.xhtml"),
        ])
    }

    func testParseLinkProperties() throws {
        let sut = try parseManifest("links-properties", at: "/EPUB/content.opf").manifest

        XCTAssertEqual(sut.readingOrder.count, 8)
        XCTAssertEqual(sut.readingOrder[0], link(id: "chapter01", href: "/EPUB/chapter01.xhtml", rels: [.contents], properties: Properties([
            "contains": ["mathml"],
            "orientation": "auto",
            "overflow": "auto",
            "page": "right",
            "layout": "fixed",
        ])))
        XCTAssertEqual(sut.readingOrder[1], link(id: "chapter02", href: "/EPUB/chapter02.xhtml", properties: Properties([
            "contains": ["remote-resources"],
            "orientation": "landscape",
            "overflow": "paginated",
            "page": "left",
            "layout": "reflowable",
        ])))
        XCTAssertEqual(sut.readingOrder[2], link(id: "chapter03", href: "/EPUB/chapter03.xhtml", properties: Properties([
            "contains": ["js", "svg"],
            "orientation": "portrait",
            "overflow": "scrolled",
            "page": "center",
        ])))
        XCTAssertEqual(sut.readingOrder[3], link(id: "chapter04", href: "/EPUB/chapter04.xhtml", properties: Properties([
            "contains": ["onix", "xmp"],
            "overflow": "scrolled",
            "spread": "none",
        ])))
        XCTAssertEqual(sut.readingOrder[4], link(id: "chapter05", href: "/EPUB/chapter05.xhtml", properties: Properties([
            "spread": "both",
        ])))
        XCTAssertEqual(sut.readingOrder[5], link(id: "chapter06", href: "/EPUB/chapter06.xhtml", properties: Properties([
            "spread": "landscape",
        ])))
        XCTAssertEqual(sut.readingOrder[6], link(id: "chapter07", href: "/EPUB/chapter07.xhtml", properties: Properties([
            "spread": "none",
        ])))
        XCTAssertEqual(sut.readingOrder[7], link(id: "chapter08", href: "/EPUB/chapter08.xhtml", properties: Properties([
            "spread": "both",
        ])))
    }

    func testParseEPUB2Cover() throws {
        let sut = try parseManifest("cover-epub2", at: "/EPUB/content.opf").manifest

        XCTAssertEqual(sut.resources, [
            link(id: "my-cover", href: "/EPUB/cover.jpg", type: "image/jpeg", rels: [.cover]),
        ])
    }

    func testParseEPUB3Cover() throws {
        let sut = try parseManifest("cover-epub3", at: "/EPUB/content.opf").manifest

        XCTAssertEqual(sut.resources, [
            link(id: "my-cover", href: "/EPUB/cover.jpg", type: "image/jpeg", rels: [.cover]),
        ])
    }

    // MARK: - Toolkit

    func parseManifest(_ name: String, at path: String = "/EPUB/content.opf", displayOptions: String? = nil) throws -> (manifest: Manifest, version: String) {
        let parts = try OPFParser(
            basePath: path,
            data: fixtures.data(at: "\(name).opf"),
            fallbackTitle: "title",
            displayOptionsData: displayOptions.map { fixtures.data(at: "\($0).xml") },
            encryptions: [:]
        ).parsePublication()

        return (Manifest(
            metadata: parts.metadata,
            readingOrder: parts.readingOrder,
            resources: parts.resources
        ), parts.version)
    }

    func link(id: String? = nil, href: String, type: String? = nil, templated: Bool = false, title: String? = nil, rels: [LinkRelation] = [], properties: Properties = .init(), duration: Double? = nil, children: [Link] = []) -> Link {
        var properties = properties.otherProperties
        if let id = id {
            properties["id"] = id
        }
        return Link(href: href, type: type, templated: templated, title: title, rels: rels, properties: Properties(properties), duration: duration, children: children)
    }
}
