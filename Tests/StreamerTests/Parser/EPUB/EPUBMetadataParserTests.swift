//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumFuzi
import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class EPUBMetadataParserTests: XCTestCase {
    let fixtures = Fixtures(path: "OPF")

    func testParseFullMetadata() throws {
        let sut = try parseMetadata("full-metadata")

        XCTAssertEqual(sut, Metadata(
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
            layout: .fixed,
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
                "http://www.idpf.org/vocab/rendition/#flow": "scrolled-doc",
                "http://www.idpf.org/vocab/rendition/#orientation": "landscape",
                "http://www.idpf.org/vocab/rendition/#spread": "both",
            ]
        ))
    }

    func testParseMinimalMetadata() throws {
        let sut = try parseMetadata("minimal")

        XCTAssertEqual(sut, Metadata(
            conformsTo: [.epub],
            title: "Alice's Adventures in Wonderland",
            layout: .reflowable
        ))
    }

    func testParseWithNamespacesPrefix() throws {
        let sut = try parseMetadata("with-namespaces-prefix")

        XCTAssertEqual(sut, Metadata(
            conformsTo: [.epub],
            title: "Alice's Adventures in Wonderland",
            layout: .reflowable
        ))
    }

    /// Old EPUB 2 files sometimes contain the `dc` tags under `dc-metadata` and `x-metadata`.
    /// See http://idpf.org/epub/20/spec/OPF_2.0_final_spec.html#Section2.2
    func testParseUnderDCMetadataElement() throws {
        let sut = try parseMetadata("dc-metadata")

        XCTAssertEqual(sut.identifier, "urn:uuid:1a16ce38-82bd-4e9b-861e-773c2e787a50")
        XCTAssertEqual(sut.title, "Alice's Adventures in Wonderland")
        XCTAssertEqual(sut.modified, "2012-04-02T12:47:00Z".dateFromISO8601)
        XCTAssertEqual(sut.authors, [Contributor(name: "Lewis Carroll")])
    }

    func testParseMainTitle() throws {
        let sut = try parseMetadata("title-main")
        XCTAssertEqual(sut.title, "Main title takes precedence")
    }

    func testParseLocalizedTitles() throws {
        let sut = try parseMetadata("title-localized")
        XCTAssertEqual(sut.localizedTitle, try LocalizedString(json: [
            "en": "Alice's Adventures in Wonderland",
            "fr": "Les Aventures d'Alice au pays des merveilles",
        ]))
        XCTAssertEqual(sut.localizedSubtitle, try LocalizedString(json: [
            "en-GB": "Alice returns to the magical world from her childhood adventure",
            "fr": "Alice retourne dans le monde magique de ses aventures d'enfance.",
        ]))
    }

    func testParseMultipleSubtitles() throws {
        let sut = try parseMetadata("title-multiple-subtitles")
        XCTAssertEqual(sut.subtitle, "Subtitle 2")
    }

    func testParseSortAsEPUB3() throws {
        let sut = try parseMetadata("sortAs-epub3")
        XCTAssertEqual(sut.sortAs, "Aventures")
    }

    func testParseSortAsEPUB2() throws {
        let sut = try parseMetadata("sortAs-epub2")
        XCTAssertEqual(sut.sortAs, "Aventures")
    }

    func testParseUniqueIdentifier() throws {
        let sut = try parseMetadata("identifier-unique")
        XCTAssertEqual(sut.identifier, "urn:uuid:2")
    }

    func testParseDateEPUB3() throws {
        let sut = try parseMetadata("dates-epub3")
        XCTAssertEqual(sut.published, "1865-07-04".dateFromISO8601)
        XCTAssertEqual(sut.modified, "2012-04-02T12:47:00Z".dateFromISO8601)
    }

    func testParseDateEPUB2() throws {
        let sut = try parseMetadata("dates-epub2")
        XCTAssertEqual(sut.published, "1865-07-04".dateFromISO8601)
        XCTAssertEqual(sut.modified, "2012-04-02T12:47:00Z".dateFromISO8601)
    }

    func testParseContributors() throws {
        let sut = try parseMetadata("contributors")

        XCTAssertEqual(sut, Metadata(
            conformsTo: [.epub],
            title: "Alice's Adventures in Wonderland",
            authors: [
                Contributor(name: "Author 1"),
                Contributor(name: "Author 3"),
                Contributor(name: "Author 4"),
                Contributor(name: "Author A"),
                Contributor(name: "Author 2"),
                Contributor(name: "Cameleon 1"),
                Contributor(name: "Cameleon A"),
            ],
            translators: [Contributor(name: "Translator")],
            editors: [Contributor(name: "Editor")],
            artists: [Contributor(name: "Artist")],
            illustrators: [
                Contributor(name: "Illustrator 1"),
                Contributor(name: "Illustrator 2", sortAs: "sorting"),
                Contributor(name: "Illustrator A", sortAs: "sorting"),
            ],
            letterers: [],
            pencilers: [],
            colorists: [Contributor(name: "Colorist")],
            inkers: [],
            narrators: [Contributor(name: "Narrator")],
            contributors: [
                Contributor(name: "Contributor 1"),
                Contributor(name: "Unknown", roles: ["unknown"]),
                Contributor(name: "Contributor A"),
            ],
            publishers: [
                Contributor(name: "Publisher 1"),
                Contributor(name: "Publisher A"),
                Contributor(name: "Publisher B"),
                Contributor(name: "Publisher 2"),
            ],
            imprints: [],
            layout: .reflowable
        ))
    }

    func testParseSingleSubjects() throws {
        let sut = try parseMetadata("subjects-single")
        XCTAssertEqual(sut.subjects, [
            Subject(name: "apple", scheme: "thema", code: "DCA"),
            Subject(name: "banana", scheme: "thema", code: "DCA"),
            Subject(name: "pear", scheme: "thema", code: "DCA"),
        ])
    }

    func testParseMultipleSubjects() throws {
        let sut = try parseMetadata("subjects-multiple")
        XCTAssertEqual(sut.subjects, [
            Subject(name: "fiction"),
            Subject(name: "apple; banana,  pear", scheme: "thema", code: "DCA"),
        ])
    }

    func testParseLocalizedSubjects() throws {
        let sut = try parseMetadata("subjects-localized")
        XCTAssertEqual(sut.subjects, [
            Subject(name: LocalizedString.localized([
                "en": "fantasy",
                "fr": "fantastique",
            ])),
        ])
    }

    func testParseCollectionsEPUB2() throws {
        let sut = try parseMetadata("collections-epub2")
        XCTAssertEqual(sut.belongsToSeries, [
            Metadata.Collection(name: "Classic Anthology", position: 1.5),
        ])
        XCTAssertEqual(sut.belongsToCollections, [])
    }

    func testParseCollectionsEPUB3() throws {
        let sut = try parseMetadata("collections-epub3")
        XCTAssertEqual(sut.belongsToSeries, [
            Metadata.Collection(name: LocalizedString.localized([
                "en": "Series A",
                "fr": "Série A",
            ]), position: 2),
            Metadata.Collection(name: "Series B"),
        ])
        XCTAssertEqual(sut.belongsToCollections, [
            Metadata.Collection(name: "Collection A", identifier: "col-a", sortAs: "ColA", position: 1.5),
            Metadata.Collection(name: "Collection B"),
        ])
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
        XCTAssertEqual(sut.layout, .fixed)
    }

    func testParseEPUB2Accessibility() throws {
        let sut = try parseMetadata("accessibility-epub2")
        XCTAssertEqual(
            sut.accessibility,
            Accessibility(
                conformsTo: [.epubA11y10WCAG20A, .epubA11y11WCAG20AAA, .epubA11y11WCAG21AA],
                certification: Accessibility.Certification(
                    certifiedBy: "Accessibility Testers Group",
                    credential: "DAISY OK",
                    report: "https://example.com/a11y-report/"
                ),
                summary: "The publication contains structural and page navigation.",
                accessModes: [.textual, .visual],
                accessModesSufficient: [[.textual], [.textual, .visual]],
                features: [.structuralNavigation, .alternativeText],
                hazards: [.motionSimulation, .noSoundHazard],
                exemptions: [.eaaMicroenterprise, .eaaFundamentalAlteration, .eaaDisproportionateBurden]
            )
        )
        // Checks that the a11y metadata are not added to otherMetadata.
        XCTAssertTrue(sut.otherMetadata.isEmpty)
    }

    func testParseEPUB3Accessibility() throws {
        let sut = try parseMetadata("accessibility-epub3")
        XCTAssertEqual(
            sut.accessibility,
            Accessibility(
                conformsTo: [.epubA11y10WCAG20A, .epubA11y11WCAG20AAA, .epubA11y11WCAG21AA],
                certification: Accessibility.Certification(
                    certifiedBy: "Accessibility Testers Group",
                    credential: "DAISY OK",
                    report: "https://example.com/a11y-report/"
                ),
                summary: "The publication contains structural and page navigation.",
                accessModes: [.textual, .visual],
                accessModesSufficient: [[.textual], [.textual, .visual]],
                features: [.structuralNavigation, .alternativeText],
                hazards: [.motionSimulation, .noSoundHazard],
                exemptions: [.eaaMicroenterprise, .eaaFundamentalAlteration, .eaaDisproportionateBurden]
            )
        )
        // Checks that the a11y metadata are not added to otherMetadata.
        XCTAssertTrue(sut.otherMetadata.isEmpty)
    }

    func testParseEPUB2TDM() throws {
        let sut = try parseMetadata("tdm-epub2")
        XCTAssertEqual(
            sut.tdm,
            TDM(
                reservation: .all,
                policy: HTTPURL(string: "https://provider.com/policies/policy.json")!
            )
        )
    }

    func testParseEPUB3TDM() throws {
        let sut = try parseMetadata("tdm-epub3")
        XCTAssertEqual(
            sut.tdm,
            TDM(
                reservation: .all,
                policy: HTTPURL(string: "https://provider.com/policies/policy.json")!
            )
        )
    }

    // MARK: - Toolkit

    func parseMetadata(_ name: String, displayOptions: String? = nil) throws -> Metadata {
        func parseDocument(named name: String, type: String) throws -> ReadiumFuzi.XMLDocument {
            try XMLDocument(data: fixtures.data(at: "\(name).\(type)"))
        }

        let document = try parseDocument(named: name, type: "opf")
        return try EPUBMetadataParser(
            document: document,
            displayOptions: displayOptions.map { try parseDocument(named: $0, type: "xml") },
            metas: OPFMetaList(document: document)
        ).parse()
    }
}
