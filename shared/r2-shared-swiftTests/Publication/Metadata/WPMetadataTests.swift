//
//  WPMetadataTests.swift
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

class WPMetadataTests: XCTestCase {
    
    func testParseReadingProgression() {
        XCTAssertEqual(WPReadingProgression(rawValue: "rtl"), .rtl)
        XCTAssertEqual(WPReadingProgression(rawValue: "ltr"), .ltr)
        XCTAssertEqual(WPReadingProgression(rawValue: "auto"), .auto)
    }

    func testReadingProgressionDefaultsToAuto() {
        XCTAssertEqual(try WPMetadata(json: ["title": "t"]).readingProgression, .auto)
        XCTAssertEqual(WPMetadata(title: "t").readingProgression, .auto)
    }
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? WPMetadata(json: ["title": "Title"]),
            WPMetadata(title: "Title")
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try WPMetadata(json: [
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
                "rendition": [
                    "layout": "fixed"
                ]
            ]),
            WPMetadata(
                identifier: "1234",
                type: "epub",
                title: ["en": "Title", "fr": "Titre"],
                subtitle: ["en": "Subtitle", "fr": "Sous-titre"],
                modified: Date(timeIntervalSinceReferenceDate: 45387),
                published: Date(timeIntervalSinceReferenceDate: 0),
                languages: ["en", "fr"],
                sortAs: "sort key",
                subjects: [WPSubject(name: "Science Fiction"), WPSubject(name: "Fantasy")],
                authors: [WPContributor(name: "Author")],
                translators: [WPContributor(name: "Translator")],
                editors: [WPContributor(name: "Editor")],
                artists: [WPContributor(name: "Artist")],
                illustrators: [WPContributor(name: "Illustrator")],
                letterers: [WPContributor(name: "Letterer")],
                pencilers: [WPContributor(name: "Penciler")],
                colorists: [WPContributor(name: "Colorist")],
                inkers: [WPContributor(name: "Inker")],
                narrators: [WPContributor(name: "Narrator")],
                contributors: [WPContributor(name: "Contributor")],
                publishers: [WPContributor(name: "Publisher")],
                imprints: [WPContributor(name: "Imprint")],
                readingProgression: .rtl,
                description: "Description",
                duration: 4.24,
                numberOfPages: 240,
                belongsTo: .init(
                    collections: [WPContributor(name: "Collection")],
                    series: [WPContributor(name: "Series")]
                ),
                rendition: EPUBRendition(layout: .fixed)
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try WPMetadata(json: []))
    }
    
    func testParseJSONWithSingleLanguage() {
        XCTAssertEqual(
            try WPMetadata(json: [
                "title": "Title",
                "language": "fr"
            ]),
            WPMetadata(
                title: "Title",
                languages: ["fr"]
            )
        )
    }
    
    func testParseJSONOtherMetadata() {
        XCTAssertEqual(
            try? WPMetadata(json: [
                "title": "Title",
                "other-metadata1": "value",
                "other-metadata2": [42],
            ]),
            WPMetadata(
                title: "Title",
                otherMetadata: [
                    "other-metadata1": "value",
                    "other-metadata2": [42]
                ]
            )
        )
    }
    
    func testParseJSONRequiresTitle() {
        XCTAssertThrowsError(try WPMetadata(json: ["duration": 4.24]))
    }

    func testParseJSONRequiresPositiveDuration() {
        XCTAssertEqual(
            try? WPMetadata(json: ["title": "t", "duration": -20]),
            WPMetadata(title: "t")
        )
    }
    
    func testParseJSONRequiresPositiveNumberOfPages() {
        XCTAssertEqual(
            try? WPMetadata(json: ["title": "t", "numberOfPages": -20]),
            WPMetadata(title: "t")
        )
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            WPMetadata(title: "Title").json,
            [
                "title": "Title",
                "readingProgression": "auto"
            ]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            WPMetadata(
                identifier: "1234",
                type: "epub",
                title: ["en": "Title", "fr": "Titre"],
                subtitle: ["en": "Subtitle", "fr": "Sous-titre"],
                modified: Date(timeIntervalSinceReferenceDate: 45387),
                published: Date(timeIntervalSinceReferenceDate: 0),
                languages: ["en", "fr"],
                sortAs: "sort key",
                subjects: [WPSubject(name: "Science Fiction"), WPSubject(name: "Fantasy")],
                authors: [WPContributor(name: "Author")],
                translators: [WPContributor(name: "Translator")],
                editors: [WPContributor(name: "Editor")],
                artists: [WPContributor(name: "Artist")],
                illustrators: [WPContributor(name: "Illustrator")],
                letterers: [WPContributor(name: "Letterer")],
                pencilers: [WPContributor(name: "Penciler")],
                colorists: [WPContributor(name: "Colorist")],
                inkers: [WPContributor(name: "Inker")],
                narrators: [WPContributor(name: "Narrator")],
                contributors: [WPContributor(name: "Contributor")],
                publishers: [WPContributor(name: "Publisher")],
                imprints: [WPContributor(name: "Imprint")],
                readingProgression: .rtl,
                description: "Description",
                duration: 4.24,
                numberOfPages: 240,
                belongsTo: .init(
                    collections: [WPContributor(name: "Collection")],
                    series: [WPContributor(name: "Series")]
                ),
                rendition: EPUBRendition(layout: .fixed),
                otherMetadata: [
                    "other-metadata1": "value"
                ]
            ).json,
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
                "rendition": [
                    "layout": "fixed"
                ],
                "other-metadata1": "value"
            ]
        )
    }

}
