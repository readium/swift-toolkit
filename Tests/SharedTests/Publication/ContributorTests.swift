//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class ContributorTests: XCTestCase {
    func testParseJSONString() {
        XCTAssertEqual(
            try? Contributor(json: "Thom Yorke"),
            Contributor(name: "Thom Yorke")
        )
    }

    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Contributor(json: ["name": "Colin Greenwood"]),
            Contributor(name: "Colin Greenwood")
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            try? Contributor(json: [
                "name": "Colin Greenwood",
                "identifier": "colin",
                "sortAs": "greenwood",
                "role": "bassist",
                "position": 4,
                "links": [
                    ["href": "http://link1"],
                    ["href": "http://link2"],
                ],
            ] as JSONValue),
            Contributor(
                name: "Colin Greenwood",
                identifier: "colin",
                sortAs: "greenwood",
                roles: ["bassist"],
                position: 4,
                links: [
                    Link(href: "http://link1"),
                    Link(href: "http://link2"),
                ]
            )
        )
    }

    func testParseJSONWithMultipleRoles() {
        XCTAssertEqual(
            try? Contributor(json: [
                "name": "Thom Yorke",
                "role": ["singer", "guitarist"],
            ] as JSONValue),
            Contributor(
                name: "Thom Yorke",
                roles: ["singer", "guitarist"]
            )
        )
    }

    func testParseJSONRequiresName() {
        XCTAssertThrowsError(try Contributor(json: [
            "identifier": "c1",
        ]))
    }

    func testParseJSONArray() {
        XCTAssertEqual(
            [Contributor](json: [
                "Thom Yorke",
                [
                    "name": ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    "role": "guitarist",
                ] as JSONValue,
            ] as JSONValue),
            [
                Contributor(name: "Thom Yorke"),
                Contributor(
                    name: ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    roles: ["guitarist"]
                ),
            ]
        )
    }

    func testParseJSONArrayWhenNil() {
        XCTAssertEqual(
            [Contributor](json: nil),
            []
        )
    }

    func testParseJSONArrayIgnoresInvalidContributors() {
        XCTAssertEqual(
            [Contributor](json: [
                "Thom Yorke",
                [
                    "role": "guitarist",
                ],
            ] as JSONValue),
            [
                Contributor(name: "Thom Yorke"),
            ]
        )
    }

    func testParseJSONArrayWhenString() {
        XCTAssertEqual(
            [Contributor](json: "Thom Yorke"),
            [Contributor(name: "Thom Yorke")]
        )
    }

    func testParseJSONArrayWhenSingleObject() {
        XCTAssertEqual(
            [Contributor](json: [
                "name": ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                "role": "guitarist",
            ] as JSONValue),
            [
                Contributor(
                    name: ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    roles: ["guitarist"]
                ),
            ]
        )
    }

    func testGetMinimalJSON() {
        XCTAssertEqual(
            Contributor(name: "Thom Yorke").jsonObject,
            ["name": "Thom Yorke"]
        )
    }

    func testGetFullJSON() {
        XCTAssertEqual(
            Contributor(
                name: ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                identifier: "jonny",
                sortAs: "greenwood",
                roles: ["guitarist", "pianist"],
                position: 2.5,
                links: [
                    Link(href: "http://link1"),
                    Link(href: "http://link2"),
                ]
            ).jsonObject,
            [
                "name": ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                "identifier": "jonny",
                "sortAs": "greenwood",
                "role": ["guitarist", "pianist"],
                "position": 2.5,
                "links": [
                    ["href": "http://link1", "templated": false] as JSONValue,
                    ["href": "http://link2", "templated": false],
                ],
            ] as [String: JSONValue]
        )
    }

    func testGetJSONArray() {
        XCTAssertEqual(
            [
                Contributor(name: "Thom Yorke"),
                Contributor(
                    name: ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    roles: ["guitarist"]
                ),
            ].json,
            [
                [
                    "name": "Thom Yorke",
                ] as [String: JSONValue],
                [
                    "name": ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    "role": ["guitarist"],
                ],
            ]
        )
    }
}
