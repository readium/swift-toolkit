//
//  Copyright 2025 Readium Foundation. All rights reserved.
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
            ] as [String: Any]),
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
            ] as [String: Any]),
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
                ] as [String: Any],
            ] as [Any]),
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
            ] as [Any]),
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
            ] as [String: Any]),
            [
                Contributor(
                    name: ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    roles: ["guitarist"]
                ),
            ]
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            Contributor(name: "Thom Yorke").json,
            ["name": "Thom Yorke"]
        )
    }

    func testGetFullJSON() {
        AssertJSONEqual(
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
            ).json,
            [
                "name": ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                "identifier": "jonny",
                "sortAs": "greenwood",
                "role": ["guitarist", "pianist"],
                "position": 2.5,
                "links": [
                    ["href": "http://link1", "templated": false] as [String: Any],
                    ["href": "http://link2", "templated": false],
                ],
            ] as [String: Any]
        )
    }

    func testGetJSONArray() {
        AssertJSONEqual(
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
                ] as [String: Any],
                [
                    "name": ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    "role": ["guitarist"],
                ],
            ]
        )
    }
}
