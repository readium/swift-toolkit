//
//  Copyright 2026 Readium Foundation. All rights reserved.
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
            ] as JSONValue),
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

    func testGetMinimalJSON() {
        XCTAssertEqual(
            Subject(name: "Fantasy").jsonObject,
            ["name": "Fantasy"]
        )
    }

    func testGetFullJSON() {
        XCTAssertEqual(
            Subject(
                name: "Science Fiction",
                sortAs: "science-fiction",
                scheme: "http://scheme",
                code: "CODE",
                links: [
                    Link(href: "subject1"),
                    Link(href: "subject2"),
                ]
            ).jsonObject,
            [
                "name": "Science Fiction",
                "sortAs": "science-fiction",
                "scheme": "http://scheme",
                "code": "CODE",
                "links": [
                    ["href": "subject1", "templated": false] as JSONValue,
                    ["href": "subject2", "templated": false],
                ],
            ] as [String: JSONValue]
        )
    }
}
