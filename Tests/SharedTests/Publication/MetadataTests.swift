//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class MetadataTests: XCTestCase {
    let fullMetadata = Metadata(
        identifier: "1234",
        type: "epub",
        conformsTo: [.epub, .pdf],
        title: ["en": "Title", "fr": "Titre"],
        subtitle: ["en": "Subtitle", "fr": "Sous-titre"],
        accessibility: Accessibility(conformsTo: [.epubA11y10WCAG20A]),
        modified: Date(timeIntervalSinceReferenceDate: 45387),
        published: Date(timeIntervalSinceReferenceDate: 0),
        languages: ["en", "fr"],
        sortAs: "sort key",
        subjects: [Subject(name: "Science Fiction"), Subject(name: "Fantasy")],
        authors: [Contributor(name: "Author")],
        translators: [Contributor(name: "Translator")],
        editors: [Contributor(name: "Editor")],
        artists: [Contributor(name: "Artist")],
        illustrators: [Contributor(name: "Illustrator")],
        letterers: [Contributor(name: "Letterer")],
        pencilers: [Contributor(name: "Penciler")],
        colorists: [Contributor(name: "Colorist")],
        inkers: [Contributor(name: "Inker")],
        narrators: [Contributor(name: "Narrator")],
        contributors: [Contributor(name: "Contributor")],
        publishers: [Contributor(name: "Publisher")],
        imprints: [Contributor(name: "Imprint")],
        readingProgression: .rtl,
        description: "Description",
        duration: 4.24,
        numberOfPages: 240,
        belongsTo: [
            "schema:Periodical": [Contributor(name: "Periodical")],
        ],
        belongsToCollections: [Contributor(name: "Collection")],
        belongsToSeries: [Contributor(name: "Series")],
        tdm: TDM(reservation: .all, policy: HTTPURL(string: "https://tdm.com")!),
        otherMetadata: [
            "other-metadata1": "value",
            "other-metadata2": [42],
        ]
    )

    func testParseReadingProgression() {
        XCTAssertEqual(ReadingProgression(rawValue: "rtl"), .rtl)
        XCTAssertEqual(ReadingProgression(rawValue: "ltr"), .ltr)
        XCTAssertEqual(ReadingProgression(rawValue: "auto"), .auto)
    }

    func testReadingProgressionDefaultsToAuto() {
        XCTAssertEqual(try Metadata(json: ["title": "t"]).readingProgression, .auto)
        XCTAssertEqual(Metadata(title: "t").readingProgression, .auto)
    }

    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Metadata(json: ["title": "Title"]),
            Metadata(title: "Title")
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            try Metadata(json: [
                "identifier": "1234",
                "@type": "epub",
                "conformsTo": [
                    "https://readium.org/webpub-manifest/profiles/epub",
                    "https://readium.org/webpub-manifest/profiles/pdf",
                ],
                "title": ["en": "Title", "fr": "Titre"],
                "subtitle": ["en": "Subtitle", "fr": "Sous-titre"],
                "accessibility": ["conformsTo": "http://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-a"],
                "modified": "2001-01-01T12:36:27+0000",
                "published": "2001-01-01",
                "language": ["en", "fr"],
                "sortAs": "sort key",
                "subject": ["Science Fiction", "Fantasy"],
                "author": "Author",
                "translator": "Translator",
                "editor": "Editor",
                "artist": "Artist",
                "illustrator": "Illustrator",
                "letterer": "Letterer",
                "penciler": "Penciler",
                "colorist": "Colorist",
                "inker": "Inker",
                "narrator": "Narrator",
                "contributor": "Contributor",
                "publisher": "Publisher",
                "imprint": "Imprint",
                "readingProgression": "rtl",
                "description": "Description",
                "duration": 4.24,
                "numberOfPages": 240,
                "belongsTo": [
                    "collection": "Collection",
                    "series": "Series",
                    "schema:Periodical": "Periodical",
                ],
                "tdm": [
                    "reservation": "all",
                    "policy": "https://tdm.com",
                ],
                "other-metadata1": "value",
                "other-metadata2": [42],
            ] as [String: Any]),
            fullMetadata
        )
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Metadata(json: [] as [Any]))
    }

    func testParseJSONWithSingleProfile() {
        XCTAssertEqual(
            try Metadata(json: [
                "title": "Title",
                "conformsTo": "https://readium.org/webpub-manifest/profiles/divina",
            ]),
            Metadata(
                conformsTo: [.divina],
                title: "Title"
            )
        )
    }

    func testParseJSONWithSingleLanguage() {
        XCTAssertEqual(
            try Metadata(json: [
                "title": "Title",
                "language": "fr",
            ]),
            Metadata(
                title: "Title",
                languages: ["fr"]
            )
        )
    }

    func testParseJSONRequiresTitle() {
        XCTAssertThrowsError(try Metadata(json: ["duration": 4.24]))
    }

    func testParseJSONRequiresPositiveDuration() {
        XCTAssertEqual(
            try? Metadata(json: ["title": "t", "duration": -20] as [String: Any]),
            Metadata(title: "t")
        )
    }

    func testParseJSONRequiresPositiveNumberOfPages() {
        XCTAssertEqual(
            try? Metadata(json: ["title": "t", "numberOfPages": -20] as [String: Any]),
            Metadata(title: "t")
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            Metadata(title: "Title").json,
            [
                "title": "Title",
                "readingProgression": "auto",
            ]
        )
    }

    func testGetFullJSON() {
        AssertJSONEqual(
            fullMetadata.json,
            [
                "identifier": "1234",
                "@type": "epub",
                "conformsTo": [
                    "https://readium.org/webpub-manifest/profiles/epub",
                    "https://readium.org/webpub-manifest/profiles/pdf",
                ],
                "title": ["en": "Title", "fr": "Titre"],
                "subtitle": ["en": "Subtitle", "fr": "Sous-titre"],
                "accessibility": [
                    "conformsTo": ["http://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-a"],
                ],
                "modified": "2001-01-01T12:36:27+0000",
                "published": "2001-01-01T00:00:00+0000",
                "language": ["en", "fr"],
                "sortAs": "sort key",
                "subject": [
                    ["name": "Science Fiction"],
                    ["name": "Fantasy"],
                ],
                "author": [["name": "Author"]],
                "translator": [["name": "Translator"]],
                "editor": [["name": "Editor"]],
                "artist": [["name": "Artist"]],
                "illustrator": [["name": "Illustrator"]],
                "letterer": [["name": "Letterer"]],
                "penciler": [["name": "Penciler"]],
                "colorist": [["name": "Colorist"]],
                "inker": [["name": "Inker"]],
                "narrator": [["name": "Narrator"]],
                "contributor": [["name": "Contributor"]],
                "publisher": [["name": "Publisher"]],
                "imprint": [["name": "Imprint"]],
                "readingProgression": "rtl",
                "description": "Description",
                "duration": 4.24,
                "numberOfPages": 240,
                "belongsTo": [
                    "collection": [["name": "Collection"]],
                    "series": [["name": "Series"]],
                    "schema:Periodical": [["name": "Periodical"]],
                ],
                "tdm": [
                    "reservation": "all",
                    "policy": "https://tdm.com",
                ],
                "other-metadata1": "value",
                "other-metadata2": [42],
            ] as [String: Any]
        )
    }

    private func makeMetadata(languages: [String], readingProgression: ReadingProgression) -> Metadata {
        Metadata(title: "", languages: languages, readingProgression: readingProgression)
    }
}
