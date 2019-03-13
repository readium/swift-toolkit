//
//  ContributorTests.swift
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
                    ["href": "http://link2"]
                ]
            ]),
            Contributor(
                name: "Colin Greenwood",
                identifier: "colin",
                sortAs: "greenwood",
                roles: ["bassist"],
                position: 4,
                links: [
                    Link(href: "http://link1"),
                    Link(href: "http://link2")
                ]
            )
        )
    }
    
    func testParseJSONWithMultipleRoles() {
        XCTAssertEqual(
            try? Contributor(json: [
                "name": "Thom Yorke",
                "role": ["singer", "guitarist"]
            ]),
            Contributor(
                name: "Thom Yorke",
                roles: ["singer", "guitarist"]
            )
        )
    }
    
    func testParseJSONRequiresName() {
        XCTAssertThrowsError(try Contributor(json: [
            "identifier": "c1"
        ]))
    }
    
    func testParseJSONArray() {
        XCTAssertEqual(
            [Contributor](json: [
                "Thom Yorke",
                [
                    "name": ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    "role": "guitarist"
                ]
            ]),
            [
                Contributor(name: "Thom Yorke"),
                Contributor(
                    name: ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    roles: ["guitarist"]
                )
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
                    "role": "guitarist"
                ]
            ]),
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
                "role": "guitarist"
            ]),
            [
                Contributor(
                    name: ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    roles: ["guitarist"]
                )
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
                    Link(href: "http://link2")
                ]
            ).json,
            [
                "name": ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                "identifier": "jonny",
                "sortAs": "greenwood",
                "role": ["guitarist", "pianist"],
                "position": 2.5,
                "links": [
                    ["href": "http://link1", "templated": false],
                    ["href": "http://link2", "templated": false],
                ]
            ]
        )
    }
    
    func testGetJSONArray() {
        AssertJSONEqual(
            [
                Contributor(name: "Thom Yorke"),
                Contributor(
                    name: ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    roles: ["guitarist"]
                )
            ].json,
            [
                [
                    "name": "Thom Yorke",
                ],
                [
                    "name": ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    "role": ["guitarist"]
                ]
            ]
        )
    }
    
}
