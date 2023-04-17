//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
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
                "other-metadata1": "value",
                "other-metadata2": [42],
            ] as [String: Any]
        )
    }

    func testEffectiveReadingProgressionFallsBackOnLTR() {
        let metadata = makeMetadata(languages: [], readingProgression: .auto)
        XCTAssertEqual(metadata.effectiveReadingProgression, .ltr)
    }

    func testEffectiveReadingProgressionFallsBackOnTheProvidedReadingProgression() {
        let metadata = makeMetadata(languages: [], readingProgression: .rtl)
        XCTAssertEqual(metadata.effectiveReadingProgression, .rtl)
    }

    func testEffectiveReadingProgressionWithRTLLanguage() {
        XCTAssertEqual(makeMetadata(languages: ["zh-Hant"], readingProgression: .auto).effectiveReadingProgression, .rtl)
        XCTAssertEqual(makeMetadata(languages: ["zh-TW"], readingProgression: .auto).effectiveReadingProgression, .rtl)
        XCTAssertEqual(makeMetadata(languages: ["ar"], readingProgression: .auto).effectiveReadingProgression, .rtl)
        XCTAssertEqual(makeMetadata(languages: ["fa"], readingProgression: .auto).effectiveReadingProgression, .rtl)
        XCTAssertEqual(makeMetadata(languages: ["he"], readingProgression: .auto).effectiveReadingProgression, .rtl)
        XCTAssertEqual(makeMetadata(languages: ["he"], readingProgression: .ltr).effectiveReadingProgression, .ltr)
    }

    func testEffectiveReadingProgressionIgnoresMultipleLanguages() {
        XCTAssertEqual(makeMetadata(languages: ["ar", "fa"], readingProgression: .auto).effectiveReadingProgression, .ltr)
    }

    func testEffectiveReadingProgressionIgnoresLanguageCase() {
        XCTAssertEqual(makeMetadata(languages: ["AR"], readingProgression: .auto).effectiveReadingProgression, .rtl)
    }

    func testEffectiveReadingProgressionIgnoresLanguageRegion() {
        XCTAssertEqual(makeMetadata(languages: ["ar-foo"], readingProgression: .auto).effectiveReadingProgression, .rtl)
        // But not for ZH
        XCTAssertEqual(makeMetadata(languages: ["zh-foo"], readingProgression: .auto).effectiveReadingProgression, .ltr)
    }

    private func makeMetadata(languages: [String], readingProgression: ReadingProgression) -> Metadata {
        Metadata(title: "", languages: languages, readingProgression: readingProgression)
    }

    func testCopy() {
        let metadata = fullMetadata

        AssertJSONEqual(metadata.json, metadata.copy().json)

        let copy = metadata.copy(
            identifier: "copy-identifier",
            type: "copy-type",
            conformsTo: [.audiobook],
            title: "copy-title",
            subtitle: "copy-subtitle",
            accessibility: Accessibility(conformsTo: [.epubA11y10WCAG20AA]),
            modified: Date(timeIntervalSince1970: 42),
            published: Date(timeIntervalSince1970: 84),
            languages: ["copy-language"],
            sortAs: "copy-sortAs",
            subjects: [Subject(name: "copy-subject")],
            authors: [Contributor(name: "copy-author")],
            translators: [Contributor(name: "copy-translator")],
            editors: [Contributor(name: "copy-editor")],
            artists: [Contributor(name: "copy-artist")],
            illustrators: [Contributor(name: "copy-illustrator")],
            letterers: [Contributor(name: "copy-letterer")],
            pencilers: [Contributor(name: "copy-penciler")],
            colorists: [Contributor(name: "copy-colorist")],
            inkers: [Contributor(name: "copy-inker")],
            narrators: [Contributor(name: "copy-narrator")],
            contributors: [Contributor(name: "copy-contributor")],
            publishers: [Contributor(name: "copy-publisher")],
            imprints: [Contributor(name: "copy-imprint")],
            readingProgression: .btt,
            description: "copy-description",
            duration: 823.5,
            numberOfPages: 3298,
            belongsTo: [
                "schema:Periodical": [Metadata.Collection(name: "copy-periodical")],
            ],
            belongsToCollections: [Metadata.Collection(name: "copy-collection")],
            belongsToSeries: [Metadata.Collection(name: "copy-series")],
            otherMetadata: ["copy": true]
        )

        AssertJSONEqual(
            copy.json,
            [
                "identifier": "copy-identifier",
                "@type": "copy-type",
                "conformsTo": [
                    "https://readium.org/webpub-manifest/profiles/audiobook",
                ],
                "title": "copy-title",
                "subtitle": "copy-subtitle",
                "accessibility": ["conformsTo": ["http://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-aa"]],
                "modified": "1970-01-01T00:00:42+0000",
                "published": "1970-01-01T00:01:24+0000",
                "language": ["copy-language"],
                "sortAs": "copy-sortAs",
                "subject": [["name": "copy-subject"]],
                "author": [["name": "copy-author"]],
                "translator": [["name": "copy-translator"]],
                "editor": [["name": "copy-editor"]],
                "artist": [["name": "copy-artist"]],
                "illustrator": [["name": "copy-illustrator"]],
                "letterer": [["name": "copy-letterer"]],
                "penciler": [["name": "copy-penciler"]],
                "colorist": [["name": "copy-colorist"]],
                "inker": [["name": "copy-inker"]],
                "narrator": [["name": "copy-narrator"]],
                "contributor": [["name": "copy-contributor"]],
                "publisher": [["name": "copy-publisher"]],
                "imprint": [["name": "copy-imprint"]],
                "readingProgression": "btt",
                "description": "copy-description",
                "duration": 823.5,
                "numberOfPages": 3298,
                "belongsTo": [
                    "collection": [["name": "copy-collection"]],
                    "series": [["name": "copy-series"]],
                    "schema:Periodical": [["name": "copy-periodical"]],
                ],
                "copy": true,
            ] as [String: Any]
        )
    }
}
