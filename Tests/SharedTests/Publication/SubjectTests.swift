//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class SubjectTests: XCTestCase {
    func testParseJSONString() {
        XCTAssertEqual(
            try? Subject(json: "Fantasy"),
            Subject(name: "Fantasy")
        )
    }

    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Subject(json: ["name": "Science Fiction"]),
            Subject(name: "Science Fiction")
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            try? Subject(json: [
                "name": "Science Fiction",
                "sortAs": "science-fiction",
                "scheme": "http://scheme",
                "code": "CODE",
                "links": [
                    ["href": "subject1"],
                    ["href": "subject2"],
                ],
            ] as [String: Any]),
            Subject(
                name: "Science Fiction",
                sortAs: "science-fiction",
                scheme: "http://scheme",
                code: "CODE",
                links: [
                    Link(href: "subject1"),
                    Link(href: "subject2"),
                ]
            )
        )
    }

    func testParseJSONRequiresName() {
        XCTAssertThrowsError(try Subject(json: [
            "sortAs": "science-fiction",
        ]))
    }

    func testParseJSONArray() {
        XCTAssertEqual(
            [Subject](json: [
                "Fantasy",
                [
                    "name": "Science Fiction",
                    "scheme": "http://scheme",
                ],
            ] as [Any]),
            [
                Subject(name: "Fantasy"),
                Subject(
                    name: "Science Fiction",
                    scheme: "http://scheme"
                ),
            ]
        )
    }

    func testParseJSONArrayWhenNil() {
        XCTAssertEqual(
            [Subject](json: nil),
            []
        )
    }

    func testParseJSONArrayIgnoresInvalidSubjects() {
        XCTAssertEqual(
            [Subject](json: [
                "Fantasy",
                [
                    "code": "CODE",
                ],
            ] as [Any]),
            [
                Subject(name: "Fantasy"),
            ]
        )
    }

    func testParseJSONArrayWhenString() {
        XCTAssertEqual(
            [Subject](json: "Fantasy"),
            [Subject(name: "Fantasy")]
        )
    }

    func testParseJSONArrayWhenSingleObject() {
        XCTAssertEqual(
            [Subject](json: [
                "name": "Fantasy",
                "code": "CODE",
            ]),
            [
                Subject(
                    name: "Fantasy",
                    code: "CODE"
                ),
            ]
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            Subject(name: "Fantasy").json,
            ["name": "Fantasy"]
        )
    }

    func testGetFullJSON() {
        AssertJSONEqual(
            Subject(
                name: "Science Fiction",
                sortAs: "science-fiction",
                scheme: "http://scheme",
                code: "CODE",
                links: [
                    Link(href: "subject1"),
                    Link(href: "subject2"),
                ]
            ).json,
            [
                "name": "Science Fiction",
                "sortAs": "science-fiction",
                "scheme": "http://scheme",
                "code": "CODE",
                "links": [
                    ["href": "subject1", "templated": false] as [String: Any],
                    ["href": "subject2", "templated": false],
                ],
            ] as [String: Any]
        )
    }

    func testGetJSONArray() {
        AssertJSONEqual(
            [
                Subject(name: "Fantasy"),
                Subject(
                    name: "Science Fiction",
                    scheme: "http://scheme"
                ),
            ].json,
            [
                [
                    "name": "Fantasy",
                ],
                [
                    "name": "Science Fiction",
                    "scheme": "http://scheme",
                ],
            ]
        )
    }
}
