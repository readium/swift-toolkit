//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

struct MetadataTests {
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

    @Test func parseReadingProgression() {
        #expect(ReadingProgression(rawValue: "rtl") == .rtl)
        #expect(ReadingProgression(rawValue: "ltr") == .ltr)
        #expect(ReadingProgression(rawValue: "auto") == .auto)
    }

    @Test func readingProgressionDefaultsToAuto() throws {
        #expect(try Metadata(json: ["title": "t"])?.readingProgression == .auto)
        #expect(Metadata(title: "t").readingProgression == .auto)
    }

    @Test func parseMinimalJSON() {
        #expect(
            (try? Metadata(json: ["title": "Title"]))
                == Metadata(title: "Title")
        )
    }

    @Test func parseFullJSON() throws {
        #expect(
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
            ] as JSONValue)
                == fullMetadata
        )
    }

    @Test func parseInvalidJSON() {
        #expect(throws: (any Error).self) {
            try Metadata(json: [] as JSONValue)
        }
    }

    @Test func parseJSONWithSingleProfile() throws {
        #expect(
            try Metadata(json: [
                "title": "Title",
                "conformsTo": "https://readium.org/webpub-manifest/profiles/divina",
            ])
                == Metadata(
                    conformsTo: [.divina],
                    title: "Title"
                )
        )
    }

    @Test func parseJSONWithSingleLanguage() throws {
        #expect(
            try Metadata(json: [
                "title": "Title",
                "language": "fr",
            ])
                == Metadata(
                    title: "Title",
                    languages: ["fr"]
                )
        )
    }

    @Test func parseJSONRequiresTitle() {
        #expect(throws: (any Error).self) {
            try Metadata(json: ["duration": 4.24])
        }
    }

    @Test func parseJSONRequiresPositiveDuration() {
        #expect(
            (try? Metadata(json: ["title": "t", "duration": -20] as JSONValue))
                == Metadata(title: "t")
        )
    }

    @Test func parseJSONRequiresPositiveNumberOfPages() {
        #expect(
            (try? Metadata(json: ["title": "t", "numberOfPages": -20] as JSONValue))
                == Metadata(title: "t")
        )
    }

    @Test func languageIsTheFirstOneParsed() {
        let metadata = Metadata(title: "t", languages: ["en_US", "fr"])
        #expect(metadata.language == "en-US")
        #expect(metadata.languages == ["en_US", "fr"])
    }

    @Test func getMinimalJSON() {
        #expect(
            Metadata(title: "Title").jsonObject == [
                "title": "Title",
                "readingProgression": "auto",
            ]
        )
    }

    @Test func getFullJSON() {
        #expect(
            fullMetadata.jsonObject == [
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
            ] as [String: JSONValue]
        )
    }
}
