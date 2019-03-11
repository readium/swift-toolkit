//
//  WPLinkTests.swift
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

class WPLinkTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? WPLink(json: ["href": "http://href"]),
            WPLink(href: "http://href")
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? WPLink(json: [
                "href": "http://href",
                "type": "application/pdf",
                "templated": true,
                "title": "Link Title",
                "rel": ["publication", "cover"],
                "properties": [
                    "orientation": "landscape"
                ],
                "height": 1024,
                "width": 768,
                "bitrate": 74.2,
                "duration": 45.6,
                "children": [
                    ["href": "http://child1"],
                    ["href": "http://child2"]
                ]
            ]),
            WPLink(
                href: "http://href",
                type: "application/pdf",
                templated: true,
                title: "Link Title",
                rels: ["publication", "cover"],
                properties: WPProperties(orientation: .landscape),
                height: 1024,
                width: 768,
                bitrate: 74.2,
                duration: 45.6,
                children: [
                    WPLink(href: "http://child1"),
                    WPLink(href: "http://child2")
                ]
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try WPLink(json: ""))
    }
    
    func testParseJSONRelAsSingleString() {
        XCTAssertEqual(
            try? WPLink(json: ["href": "a", "rel": "publication"]),
            WPLink(href: "a", rels: ["publication"])
        )
    }
    
    func testParseJSONTemplatedDefaultsToFalse() {
        XCTAssertFalse(try WPLink(json: ["href": "a"]).templated)
    }
    
    func testParseJSONTemplatedAsNull() {
        XCTAssertFalse(try WPLink(json: ["href": "a", "templated": NSNull()]).templated)
        XCTAssertFalse(try WPLink(json: ["href": "a", "templated": nil]).templated)
    }

    func testParseJSONRequiresHref() {
        XCTAssertThrowsError(try WPLink(json: ["type": "application/pdf"]))
    }
    
    func testParseJSONRequiresPositiveWidth() {
        XCTAssertEqual(
            try? WPLink(json: ["href": "a", "width": -20]),
            WPLink(href: "a")
        )
    }
    
    func testParseJSONRequiresPositiveHeight() {
        XCTAssertEqual(
            try? WPLink(json: ["href": "a", "height": -20]),
            WPLink(href: "a")
        )
    }
    
    func testParseJSONRequiresPositiveBitrate() {
        XCTAssertEqual(
            try? WPLink(json: ["href": "a", "bitrate": -20]),
            WPLink(href: "a")
        )
    }
    
    func testParseJSONRequiresPositiveDuration() {
        XCTAssertEqual(
            try? WPLink(json: ["href": "a", "duration": -20]),
            WPLink(href: "a")
        )
    }

    func testParseJSONArray() {
        XCTAssertEqual(
            [WPLink](json: [
                ["href": "http://child1"],
                ["href": "http://child2"]
            ]),
            [
                WPLink(href: "http://child1"),
                WPLink(href: "http://child2")
            ]
        )
    }
    
    func testParseJSONArrayWhenNil() {
        XCTAssertEqual(
            [WPLink](json: nil),
            []
        )
    }
    
    func testParseJSONArrayIgnoresInvalidLinks() {
        XCTAssertEqual(
            [WPLink](json: [
                ["title": "Title"],
                ["href": "http://child2"]
            ]),
            [
                WPLink(href: "http://child2")
            ]
        )
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            WPLink(href: "http://href").json,
            [
                "href": "http://href",
                "templated": false
            ]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            WPLink(
                href: "http://href",
                type: "application/pdf",
                templated: true,
                title: "Link Title",
                rels: ["publication", "cover"],
                properties: WPProperties(orientation: .landscape),
                height: 1024,
                width: 768,
                bitrate: 74.2,
                duration: 45.6,
                children: [
                    WPLink(href: "http://child1"),
                    WPLink(href: "http://child2")
                ]
            ).json,
            [
                "href": "http://href",
                "type": "application/pdf",
                "templated": true,
                "title": "Link Title",
                "rel": ["publication", "cover"],
                "properties": [
                    "orientation": "landscape"
                ],
                "height": 1024,
                "width": 768,
                "bitrate": 74.2,
                "duration": 45.6,
                "children": [
                    ["href": "http://child1", "templated": false],
                    ["href": "http://child2", "templated": false]
                ]
            ]
        )
    }
    
    func testGetJSONArray() {
        AssertJSONEqual(
            [
                WPLink(href: "http://child1"),
                WPLink(href: "http://child2")
            ].json,
            [
                ["href": "http://child1", "templated": false],
                ["href": "http://child2", "templated": false]
            ]
        )
    }

}
