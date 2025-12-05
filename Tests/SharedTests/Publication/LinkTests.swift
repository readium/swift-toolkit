//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class LinkTests: XCTestCase {
    let fullLink = Link(
        href: "http://href",
        mediaType: .pdf,
        templated: true,
        title: "Link Title",
        rels: [.publication, .cover],
        properties: Properties(["orientation": "landscape"]),
        height: 1024,
        width: 768,
        bitrate: 74.2,
        duration: 45.6,
        languages: ["fr"],
        alternates: [
            Link(href: "/alternate1"),
            Link(href: "/alternate2"),
        ],
        children: [
            Link(href: "http://child1"),
            Link(href: "http://child2"),
        ]
    )

    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Link(json: ["href": "http://href"]),
            Link(href: "http://href")
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            try? Link(json: [
                "href": "http://href",
                "type": "application/pdf",
                "templated": true,
                "title": "Link Title",
                "rel": ["publication", "cover"],
                "properties": [
                    "orientation": "landscape",
                ],
                "height": 1024,
                "width": 768,
                "bitrate": 74.2,
                "duration": 45.6,
                "language": "fr",
                "alternate": [
                    ["href": "/alternate1"],
                    ["href": "/alternate2"],
                ],
                "children": [
                    ["href": "http://child1"],
                    ["href": "http://child2"],
                ],
            ] as [String: Any]),
            fullLink
        )
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Link(json: ""))
    }

    func testParseInvalidHREFWithDecodedPathInJSON() throws {
        let link = try Link(json: ["href": "01_Note de l editeur audio.mp3"])
        XCTAssertEqual(link, Link(href: "01_Note%20de%20l%20editeur%20audio.mp3"))
        XCTAssertEqual(link.url(), AnyURL(string: "01_Note%20de%20l%20editeur%20audio.mp3"))
    }

    func testParseJSONRelAsSingleString() {
        XCTAssertEqual(
            try? Link(json: ["href": "a", "rel": "publication"]),
            Link(href: "a", rels: [.publication])
        )
    }

    func testParseJSONWithTemplateURI() {
        XCTAssertEqual(
            try? Link(json: ["href": "https://catalog.feedbooks.com/search.json{?query}", "templated": true]),
            Link(href: "https://catalog.feedbooks.com/search.json{?query}", templated: true)
        )
    }

    func testParseJSONTemplatedDefaultsToFalse() {
        XCTAssertFalse(try Link(json: ["href": "a"]).templated)
    }

    func testParseJSONTemplatedAsNull() {
        XCTAssertFalse(try Link(json: ["href": "a", "templated": NSNull()] as [String: Any]).templated)
        XCTAssertFalse(try Link(json: ["href": "a", "templated": nil]).templated)
    }

    func testParseJSONMultipleLanguages() {
        XCTAssertEqual(
            try? Link(json: ["href": "a", "language": ["fr", "en"]] as [String: Any]),
            Link(href: "a", languages: ["fr", "en"])
        )
    }

    func testParseJSONRequiresHref() {
        XCTAssertThrowsError(try Link(json: ["type": "application/pdf"]))
    }

    func testParseJSONRequiresPositiveWidth() {
        XCTAssertEqual(
            try? Link(json: ["href": "a", "width": -20] as [String: Any]),
            Link(href: "a")
        )
    }

    func testParseJSONRequiresPositiveHeight() {
        XCTAssertEqual(
            try? Link(json: ["href": "a", "height": -20] as [String: Any]),
            Link(href: "a")
        )
    }

    func testParseJSONRequiresPositiveBitrate() {
        XCTAssertEqual(
            try? Link(json: ["href": "a", "bitrate": -20] as [String: Any]),
            Link(href: "a")
        )
    }

    func testParseJSONRequiresPositiveDuration() {
        XCTAssertEqual(
            try? Link(json: ["href": "a", "duration": -20] as [String: Any]),
            Link(href: "a")
        )
    }

    func testParseJSONArray() {
        XCTAssertEqual(
            [Link](json: [
                ["href": "http://child1"],
                ["href": "http://child2"],
            ]),
            [
                Link(href: "http://child1"),
                Link(href: "http://child2"),
            ]
        )
    }

    func testParseJSONArrayWhenNil() {
        XCTAssertEqual(
            [Link](json: nil),
            []
        )
    }

    func testParseJSONArrayIgnoresInvalidLinks() {
        XCTAssertEqual(
            [Link](json: [
                ["title": "Title"],
                ["href": "http://child2"],
            ]),
            [
                Link(href: "http://child2"),
            ]
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            Link(href: "http://href").json,
            [
                "href": "http://href",
                "templated": false,
            ] as [String: Any]
        )
    }

    func testGetFullJSON() {
        AssertJSONEqual(
            fullLink.json,
            [
                "href": "http://href",
                "type": "application/pdf",
                "templated": true,
                "title": "Link Title",
                "rel": ["publication", "cover"],
                "properties": [
                    "orientation": "landscape",
                ],
                "height": 1024,
                "width": 768,
                "bitrate": 74.2,
                "duration": 45.6,
                "language": ["fr"],
                "alternate": [
                    ["href": "/alternate1", "templated": false] as [String: Any],
                    ["href": "/alternate2", "templated": false],
                ],
                "children": [
                    ["href": "http://child1", "templated": false] as [String: Any],
                    ["href": "http://child2", "templated": false],
                ],
            ] as [String: Any]
        )
    }

    func testGetJSONArray() {
        AssertJSONEqual(
            [
                Link(href: "http://child1"),
                Link(href: "http://child2"),
            ].json,
            [
                ["href": "http://child1", "templated": false] as [String: Any],
                ["href": "http://child2", "templated": false],
            ]
        )
    }

    func testURLRelativeToBaseURL() throws {
        XCTAssertEqual(
            Link(href: "folder/file.html").url(relativeTo: AnyURL(string: "http://host/")!),
            AnyURL(string: "http://host/folder/file.html")!
        )
    }

    func testURLRelativeToBaseURLWithRootPrefix() throws {
        XCTAssertEqual(
            Link(href: "file.html").url(relativeTo: AnyURL(string: "http://host/folder/")!),
            AnyURL(string: "http://host/folder/file.html")!
        )
    }

    func testURLRelativeToNil() throws {
        XCTAssertEqual(
            Link(href: "http://example.com/folder/file.html").url(),
            AnyURL(string: "http://example.com/folder/file.html")!
        )
        XCTAssertEqual(
            Link(href: "folder/file.html").url(),
            AnyURL(string: "folder/file.html")!
        )
    }

    func testURLWithAbsoluteHREF() throws {
        XCTAssertEqual(
            Link(href: "http://test.com/folder/file.html").url(relativeTo: AnyURL(string: "http://host/")!),
            AnyURL(string: "http://test.com/folder/file.html")!
        )
    }

    func testURLWithInvalidHREF() {
        XCTAssertEqual(
            Link(href: "01_Note de l editeur audio.mp3").url(),
            AnyURL(string: "01_Note%20de%20l%20editeur%20audio.mp3")
        )
    }

    func testTemplateParameters() {
        XCTAssertEqual(
            Link(
                href: "/url{?x,hello,y}name{z,y,w}",
                templated: true
            ).templateParameters,
            ["x", "hello", "y", "z", "w"]
        )
    }

    func testTemplateParametersWithNoVariables() {
        XCTAssertEqual(
            Link(
                href: "/url",
                templated: true
            ).templateParameters,
            []
        )
    }

    func testTemplateParametersForNonTemplatedLink() {
        XCTAssertEqual(
            Link(href: "/url{?x,hello,y}name{z,y,w}").templateParameters,
            []
        )
    }

    func testExpandSimpleStringTemplates() {
        var link = Link(
            href: "/url{x,hello,y}name{z,y,w}",
            templated: true
        )
        link.expandTemplate(with: [
            "x": "aaa",
            "hello": "Hello, world",
            "y": "b",
            "z": "45",
            "w": "w",
        ])

        XCTAssertEqual(
            link,
            Link(href: "/urlaaa,Hello,%20world,bname45,b,w")
        )
    }

    func testExpandFormStyleAmpersandSeparatedTemplates() {
        var link = Link(
            href: "/url{?x,hello,y}name",
            templated: true
        )
        link.expandTemplate(with: [
            "x": "aaa",
            "hello": "Hello, world",
            "y": "b",
        ])
        XCTAssertEqual(
            link,
            Link(href: "/url?x=aaa&hello=Hello,%20world&y=bname")
        )
    }

    func testExpandIgnoresExtraParameters() {
        var link = Link(
            href: "/path{?search}",
            templated: true
        )
        link.expandTemplate(with: [
            "search": "banana",
            "code": "14",
        ])
        XCTAssertEqual(
            link,
            Link(href: "/path?search=banana")
        )
    }

    func testAddProperties() {
        var link = fullLink
        link.addProperties([
            "additional": "property",
            "orientation": "override",
        ])

        AssertJSONEqual(
            link.json,
            [
                "href": "http://href",
                "type": "application/pdf",
                "templated": true,
                "title": "Link Title",
                "rel": ["publication", "cover"],
                "properties": [
                    "orientation": "override",
                    "additional": "property",
                ],
                "height": 1024,
                "width": 768,
                "bitrate": 74.2,
                "duration": 45.6,
                "language": ["fr"],
                "alternate": [
                    ["href": "/alternate1", "templated": false] as [String: Any],
                    ["href": "/alternate2", "templated": false],
                ],
                "children": [
                    ["href": "http://child1", "templated": false] as [String: Any],
                    ["href": "http://child2", "templated": false],
                ],
            ] as [String: Any]
        )
    }
}
