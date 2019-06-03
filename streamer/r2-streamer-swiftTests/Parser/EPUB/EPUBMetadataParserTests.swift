//
//  EPUBMetadataParserTests.swift
//  R2StreamerTests
//
//  Created by Mickaël Menu on 29.05.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
import Fuzi
import R2Shared
@testable import R2Streamer


class EPUBMetadataParserTests: XCTestCase {
    
    func testParseFullMetadata() throws {
        let sut = try parseMetadata("full-metadata")

        XCTAssertEqual(sut, Metadata(
            identifier: "urn:uuid:7408D53A-5383-40AA-8078-5256C872AE41",
            title: "Alice's Adventures in Wonderland",
            subtitle: "Alice returns to the magical world from her childhood adventure",
            modified: "2012-04-02T12:47:00Z".dateFromISO8601,
            published: "1865-07-04".dateFromISO8601,
            languages: ["en-GB", "en"],
            subjects: [
                Subject(name: "fiction"),
                Subject(name: "classic", scheme: "thema", code: "DCA")
            ],
            authors: [Contributor(name: "Lewis Carroll")],
            publishers: [Contributor(name: "D. Appleton and Co")],
            readingProgression: .rtl,
            description: "The book description.",
            belongsToCollections: [],  // FIXME: should this be parsed?
            belongsToSeries: [],  // FIXME: should this be parsed?
            otherMetadata: [
                "source": ["Feedbooks", "Web"],
                "rights": "Public Domain",
                "rendition": [
                    "spread": "both",
                    "overflow": "scrolled",
                    "orientation": "landscape",
                    "layout": "fixed"
                ]
            ]
        ))
    }
    
    func testParseMinimalMetadata() throws {
        let sut = try parseMetadata("minimal")
        
        XCTAssertEqual(sut, Metadata(
            title: "Alice's Adventures in Wonderland",
            otherMetadata: [
                "rendition": [
                    "spread": "auto",
                    "overflow": "auto",
                    "orientation": "auto",
                    "layout": "reflowable"
                ]
            ]
        ))
    }
    
    func testParseWithNamespacesPrefix() throws {
        let sut = try parseMetadata("with-namespaces-prefix")
        
        XCTAssertEqual(sut, Metadata(
            title: "Alice's Adventures in Wonderland",
            otherMetadata: [
                "rendition": [
                    "spread": "auto",
                    "overflow": "auto",
                    "orientation": "auto",
                    "layout": "reflowable"
                ]
            ]
        ))
    }
    
    func testParseMainTitle() throws {
        let sut = try parseMetadata("main-title")
        XCTAssertEqual(sut.title, "Main title takes precedence")
    }
    
    func testParseLocalizedTitles() throws {
        let sut = try parseMetadata("localized-titles")
        XCTAssertEqual(sut.localizedTitle, try LocalizedString(json: [
            "en": "Alice's Adventures in Wonderland",
            "fr": "Les Aventures d'Alice au pays des merveilles"
        ]))
        XCTAssertEqual(sut.localizedSubtitle, try LocalizedString(json: [
            "en-GB": "Alice returns to the magical world from her childhood adventure",
            "fr": "Alice retourne dans le monde magique de ses aventures d'enfance."
        ]))
    }
    
    func testParseUniqueIdentifier() throws {
        let sut = try parseMetadata("identifier-unique")
        XCTAssertEqual(sut.identifier, "urn:uuid:2")
    }
    
    func testParseContributors() throws {
        let sut = try parseMetadata("contributors")
        
        XCTAssertEqual(sut, Metadata(
            title: "Alice's Adventures in Wonderland",
            authors: [
                Contributor(name: "Author A"),
                Contributor(name: "Author B", roles: ["aut"]),
                Contributor(name: "Author C", roles: ["aut"]),
                Contributor(name: "Cameleon A", roles: ["aut", "pbl"]),
                Contributor(name: "Author 1"),
                Contributor(name: "Author 2", roles: ["aut"]),
                Contributor(name: "Author 3", roles: ["aut"]),
                Contributor(name: "Cameleon 1", roles: ["aut", "pbl"]),
                Contributor(name: "Author 4"),
                Contributor(name: "Author 5")
            ],
            translators: [Contributor(name: "Translator", roles: ["trl"])],
            editors: [Contributor(name: "Editor", roles: ["edt"])],
            artists: [Contributor(name: "Artist", roles: ["art"])],
            illustrators: [
                Contributor(name: "Illustrator A", sortAs: "sorting", roles: ["ill"]),
                Contributor(name: "Illustrator 1", roles: ["ill"]),
                Contributor(name: "Illustrator 2", sortAs: "sorting", roles: ["ill"])
            ],
            letterers: [],
            pencilers: [],
            colorists: [Contributor(name: "Colorist", roles: ["clr"])],
            inkers: [],
            narrators: [Contributor(name: "Narrator", roles: ["nrt"])],
            contributors: [
                Contributor(name: "Contributor A"),
                Contributor(name: "Contributor 1"),
                Contributor(name: "Unknown", roles: ["unknown"])
            ],
            publishers: [
                Contributor(name: "Publisher A"),
                Contributor(name: "Cameleon A", roles: ["aut", "pbl"]),
                Contributor(name: "Publisher 1"),
                Contributor(name: "Publisher 2", roles: ["pbl"]),
                Contributor(name: "Cameleon 1", roles: ["aut", "pbl"])
            ],
            imprints: [],
            otherMetadata: [
                "rendition": [
                    "spread": "auto",
                    "overflow": "auto",
                    "orientation": "auto",
                    "layout": "reflowable"
                ]
            ]
        ))
    }
    
    func testParseReadingProgressionFromSpine() throws {
        let sut = try parseMetadata("progression-spine")
        XCTAssertEqual(sut.readingProgression, .rtl)
    }
    
    func testParseReadingProgressionFromReadingOrder() throws {
        let sut = try parseMetadata("progression-readingOrder")
        XCTAssertEqual(sut.readingProgression, .rtl)
    }
    
    func testParseReadingProgressionLTR() throws {
        let sut = try parseMetadata("progression-ltr")
        XCTAssertEqual(sut.readingProgression, .ltr)
    }
    
    func testParseReadingProgressionRTL() throws {
        let sut = try parseMetadata("progression-rtl")
        XCTAssertEqual(sut.readingProgression, .rtl)
    }
    
    func testParseReadingProgressionDefault() throws {
        let sut = try parseMetadata("progression-default")
        XCTAssertEqual(sut.readingProgression, .auto)
    }
    
    func testParseReadingProgressionWhenNoneIsDefined() throws {
        let sut = try parseMetadata("progression-none")
        XCTAssertEqual(sut.readingProgression, .auto)
    }
    
    func testParseRenditionFallbackWithDisplayOptions() throws {
        let sut = try parseMetadata("minimal", displayOptions: "displayOptions")
        XCTAssertEqual(sut.otherMetadata["rendition"] as? [String: String], [
            "spread": "auto",
            "overflow": "auto",
            "orientation": "landscape",
            "layout": "fixed"
        ])
    }

    
    // MARK: - Toolkit
    
    func parseMetadata(_ name: String, displayOptions: String? = nil) throws -> Metadata {
        func document(named name: String, type: String) throws -> XMLDocument {
            return try XMLDocument(data: try Data(
                contentsOf: SampleGenerator().getSamplesFileURL(named: "OPF/\(name)", ofType: type)!
            ))
        }
        return try EPUBMetadataParser(
            document: try document(named: name, type: "opf"),
            displayOptions: try displayOptions.map { try document(named: $0, type: "xml") }
        ).parse()
    }
    
}
