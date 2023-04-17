//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

class LinkTests: XCTestCase {
    let fullLink = Link(
        href: "http://href",
        type: "application/pdf",
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

    func testParseJSONRelAsSingleString() {
        XCTAssertEqual(
            try? Link(json: ["href": "a", "rel": "publication"]),
            Link(href: "a", rels: [.publication])
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

    func testUnknownMediaType() {
        XCTAssertEqual(Link(href: "file").mediaType, .binary)
    }

    func testMediaTypeFromType() {
        XCTAssertEqual(Link(href: "file", type: "application/epub+zip").mediaType, .epub)
        XCTAssertEqual(Link(href: "file", type: "application/pdf").mediaType, .pdf)
    }

    func testMediaTypeFromExtension() {
        XCTAssertEqual(Link(href: "file.epub").mediaType, .epub)
        XCTAssertEqual(Link(href: "file.pdf").mediaType, .pdf)
    }

    func testURLRelativeToBaseURL() {
        XCTAssertEqual(
            Link(href: "folder/file.html").url(relativeTo: URL(string: "http://host/")!),
            URL(string: "http://host/folder/file.html")!
        )
    }

    func testURLRelativeToBaseURLWithRootPrefix() {
        XCTAssertEqual(
            Link(href: "/file.html").url(relativeTo: URL(string: "http://host/folder/")!),
            URL(string: "http://host/folder/file.html")!
        )
    }

    func testURLRelativeToBaseURLWithSpecialCharacters() {
        XCTAssertEqual(
            Link(href: "folder/file with%spaces.html").url(relativeTo: URL(string: "http://host/")!),
            URL(string: "http://host/folder/file%20with%25spaces.html")!
        )
        XCTAssertEqual(
            Link(href: "folder/file with%spaces.html").url(relativeTo: URL(fileURLWithPath: "/")),
            URL(fileURLWithPath: "/folder/file with%spaces.html")
        )
        XCTAssertNil(Link(href: "folder/file with%spaces.html").url(relativeTo: nil))
        XCTAssertEqual(
            Link(href: "http://example.com/folder/file%20with%25spaces.html").url(relativeTo: nil),
            URL(string: "http://example.com/folder/file%20with%25spaces.html")
        )
        XCTAssertEqual(
            Link(href: "http://example.com/folder/file%20with%25spaces.html").url(relativeTo: URL(fileURLWithPath: "/")),
            URL(string: "http://example.com/folder/file%20with%25spaces.html")
        )
    }

    func testURLRelativeToNil() {
        XCTAssertEqual(
            Link(href: "http://example.com/folder/file.html").url(relativeTo: nil),
            URL(string: "http://example.com/folder/file.html")!
        )
        XCTAssertNil(Link(href: "folder/file.html").url(relativeTo: nil))
    }

    func testURLWithInvalidHREF() {
        XCTAssertNil(Link(href: "").url(relativeTo: URL(string: "http://test.com")!))
    }

    func testURLWithAbsoluteHREF() {
        XCTAssertEqual(
            Link(href: "http://test.com/folder/file.html").url(relativeTo: URL(string: "http://host/")!),
            URL(string: "http://test.com/folder/file.html")!
        )
    }

    func testURLWithHREFContainingInvalidCharacters() {
        XCTAssertEqual(
            Link(href: "/Cory Doctorow's/a-fc.jpg").url(relativeTo: URL(string: "http://host/folder/")),
            URL(string: "http://host/folder/Cory%20Doctorow's/a-fc.jpg")!
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
        XCTAssertEqual(
            Link(
                href: "/url{x,hello,y}name{z,y,w}",
                templated: true
            ).expandTemplate(with: [
                "x": "aaa",
                "hello": "Hello, world",
                "y": "b",
                "z": "45",
                "w": "w",
            ]),
            Link(href: "/urlaaa,Hello,%20world,bname45,b,w")
        )
    }

    func testExpandFormStyleAmpersandSeparatedTemplates() {
        XCTAssertEqual(
            Link(
                href: "/url{?x,hello,y}name",
                templated: true
            ).expandTemplate(with: [
                "x": "aaa",
                "hello": "Hello, world",
                "y": "b",
            ]),
            Link(href: "/url?x=aaa&hello=Hello,%20world&y=bname")
        )
    }

    func testExpandIgnoresExtraParameters() {
        XCTAssertEqual(
            Link(
                href: "/path{?search}",
                templated: true
            ).expandTemplate(with: [
                "search": "banana",
                "code": "14",
            ]),
            Link(href: "/path?search=banana")
        )
    }

    func testCopy() {
        let link = fullLink

        AssertJSONEqual(link.json, link.copy().json)

        let copy = link.copy(
            href: "copy-href",
            type: "copy-type",
            templated: !link.templated,
            title: "copy-title",
            rels: ["copy-rel"],
            properties: Properties(["copy": true]),
            height: 923,
            width: 482,
            bitrate: 28.42,
            duration: 542.2,
            languages: ["copy-language"],
            alternates: [Link(href: "copy-alternate")],
            children: [Link(href: "copy-children")]
        )

        AssertJSONEqual(
            copy.json,
            [
                "href": "copy-href",
                "type": "copy-type",
                "templated": !link.templated,
                "title": "copy-title",
                "rel": ["copy-rel"],
                "properties": [
                    "copy": true,
                ],
                "height": 923,
                "width": 482,
                "bitrate": 28.42,
                "duration": 542.2,
                "language": ["copy-language"],
                "alternate": [
                    ["href": "copy-alternate", "templated": false] as [String: Any],
                ],
                "children": [
                    ["href": "copy-children", "templated": false] as [String: Any],
                ],
            ] as [String: Any]
        )
    }

    func testAddingProperties() {
        let link = fullLink

        let copy = link.addingProperties([
            "additional": "property",
            "orientation": "override",
        ])

        AssertJSONEqual(
            copy.json,
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
