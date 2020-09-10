//
//  MetadataTests.swift
//  r2-shared-swiftTests
//
//  Created by Mickaël Menu on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class MetadataTests: XCTestCase {
    
    let fullMetadata = Metadata(
        identifier: "1234",
        type: "epub",
        title: ["en": "Title", "fr": "Titre"],
        subtitle: ["en": "Subtitle", "fr": "Sous-titre"],
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
        belongsToCollections: [Contributor(name: "Collection")],
        belongsToSeries: [Contributor(name: "Series")],
        otherMetadata: [
            "other-metadata1": "value",
            "other-metadata2": [42]
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
                "title": ["en": "Title", "fr": "Titre"],
                "subtitle": ["en": "Subtitle", "fr": "Sous-titre"],
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
                    "series": "Series"
                ],
                "other-metadata1": "value",
                "other-metadata2": [42]
            ]),
            fullMetadata
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Metadata(json: []))
    }
    
    func testParseJSONWithSingleLanguage() {
        XCTAssertEqual(
            try Metadata(json: [
                "title": "Title",
                "language": "fr"
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
            try? Metadata(json: ["title": "t", "duration": -20]),
            Metadata(title: "t")
        )
    }
    
    func testParseJSONRequiresPositiveNumberOfPages() {
        XCTAssertEqual(
            try? Metadata(json: ["title": "t", "numberOfPages": -20]),
            Metadata(title: "t")
        )
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            Metadata(title: "Title").json,
            [
                "title": "Title",
                "readingProgression": "auto"
            ]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            fullMetadata.json,
            [
                "identifier": "1234",
                "@type": "epub",
                "title": ["en": "Title", "fr": "Titre"],
                "subtitle": ["en": "Subtitle", "fr": "Sous-titre"],
                "modified": "2001-01-01T12:36:27+0000",
                "published": "2001-01-01T00:00:00+0000",
                "language": ["en", "fr"],
                "sortAs": "sort key",
                "subject": [
                    ["name": "Science Fiction"],
                    ["name": "Fantasy"]
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
                    "series": [["name": "Series"]]
                ],
                "other-metadata1": "value",
                "other-metadata2": [42]
            ]
        )
    }
    
    func testCopy() {
        let metadata = fullMetadata
        
        AssertJSONEqual(metadata.json, metadata.copy().json)
        
        let copy = metadata.copy(
            identifier: "copy-identifier",
            type: "copy-type",
            title: "copy-title",
            subtitle: "copy-subtitle",
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
            belongsToCollections: [Metadata.Collection(name: "copy-collection")],
            belongsToSeries: [Metadata.Collection(name: "copy-series")],
            otherMetadata: ["copy": true]
        )

        AssertJSONEqual(
            copy.json,
            [
                "identifier": "copy-identifier",
                "@type": "copy-type",
                "title": "copy-title",
                "subtitle": "copy-subtitle",
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
                    "series": [["name": "copy-series"]]
                ],
                "copy": true
            ]
        )
    }

}
