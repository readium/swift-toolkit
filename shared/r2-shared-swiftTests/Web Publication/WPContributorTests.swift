//
//  WPContributorTests.swift
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

class WPContributorTests: XCTestCase {

    func testParseJSONString() {
        XCTAssertEqual(
            try? WPContributor(json: "Thom Yorke"),
            WPContributor(name: "Thom Yorke")
        )
    }
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? WPContributor(json: ["name": "Colin Greenwood"]),
            WPContributor(name: "Colin Greenwood")
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? WPContributor(json: [
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
            WPContributor(
                name: "Colin Greenwood",
                identifier: "colin",
                sortAs: "greenwood",
                roles: ["bassist"],
                position: 4,
                links: [
                    WPLink(href: "http://link1"),
                    WPLink(href: "http://link2")
                ]
            )
        )
    }
    
    func testParseJSONWithMultipleRoles() {
        XCTAssertEqual(
            try? WPContributor(json: [
                "name": "Thom Yorke",
                "role": ["singer", "guitarist"]
            ]),
            WPContributor(
                name: "Thom Yorke",
                roles: ["singer", "guitarist"]
            )
        )
    }
    
    func testParseJSONRequiresName() {
        XCTAssertThrowsError(try WPContributor(json: [
            "identifier": "c1"
        ]))
    }
    
    func testParseJSONArray() {
        XCTAssertEqual(
            [WPContributor](json: [
                "Thom Yorke",
                [
                    "name": ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    "role": "guitarist"
                ]
            ]),
            [
                WPContributor(name: "Thom Yorke"),
                WPContributor(
                    name: ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    roles: ["guitarist"]
                )
            ]
        )
    }
    
    func testParseJSONArrayWhenNil() {
        XCTAssertEqual(
            [WPContributor](json: nil),
            []
        )
    }
    
    func testParseJSONArrayIgnoresInvalidContributors() {
        XCTAssertEqual(
            [WPContributor](json: [
                "Thom Yorke",
                [
                    "role": "guitarist"
                ]
            ]),
            [
                WPContributor(name: "Thom Yorke"),
            ]
        )
    }
    
    func testParseJSONArrayWhenString() {
        XCTAssertEqual(
            [WPContributor](json: "Thom Yorke"),
            [WPContributor(name: "Thom Yorke")]
        )
    }
    
    func testParseJSONArrayWhenSingleObject() {
        XCTAssertEqual(
            [WPContributor](json: [
                "name": ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                "role": "guitarist"
            ]),
            [
                WPContributor(
                    name: ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                    roles: ["guitarist"]
                )
            ]
        )
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            WPContributor(name: "Thom Yorke").json,
            ["name": "Thom Yorke"]
        )
    }

    func testGetFullJSON() {
        AssertJSONEqual(
            WPContributor(
                name: ["en": "Jonny Greenwood", "fr": "Jean Boisvert"],
                identifier: "jonny",
                sortAs: "greenwood",
                roles: ["guitarist", "pianist"],
                position: 2.5,
                links: [
                    WPLink(href: "http://link1"),
                    WPLink(href: "http://link2")
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
                WPContributor(name: "Thom Yorke"),
                WPContributor(
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
