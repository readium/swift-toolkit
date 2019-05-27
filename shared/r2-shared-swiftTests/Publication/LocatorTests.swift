//
//  LocatorTests.swift
//  r2-shared-swiftTests
//
//  Created by Mickaël Menu on 20.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class LocatorTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Locator(json: [
                "href": "http://locator",
                "type": "text/html"
            ]),
            Locator(
                href: "http://locator",
                type: "text/html"
            )
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? Locator(json: [
                "href": "http://locator",
                "type": "text/html",
                "title": "My Locator",
                "locations": [
                    "position": 42
                ],
                "text": [
                    "highlight": "Excerpt"
                ]
            ]),
            Locator(
                href: "http://locator",
                type: "text/html",
                title: "My Locator",
                locations: Locations(position: 42),
                text: LocatorText(highlight: "Excerpt")
            )
        )
    }
    
    func testParseNilJSON() {
        XCTAssertNil(try Locator(json: nil))
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Locator(json: ""))
    }
    
    func testMakeFromFullLink() {
        XCTAssertEqual(
            Locator(link: Link(
                href: "http://locator",
                type: "text/html",
                title: "Link title"
            )),
            Locator(
                href: "http://locator",
                type: "text/html",
                title: "Link title"
            )
        )
    }
    
    func testMakeFromMinimalLink() {
        XCTAssertEqual(
            Locator(link: Link(
                href: "http://locator"
            )),
            Locator(
                href: "http://locator",
                type: "",
                title: nil
            )
        )
    }
    
    func testMakeFromLinkWithFragment() {
        XCTAssertEqual(
            Locator(link: Link(
                href: "http://locator#page=42"
            )),
            Locator(
                href: "http://locator",
                type: "",
                locations: Locations(fragment: "page=42")
            )
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            Locator(
                href: "http://locator",
                type: "text/html"
            ).json,
            [
                "href": "http://locator",
                "type": "text/html"
            ]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            Locator(
                href: "http://locator",
                type: "text/html",
                title: "My Locator",
                locations: .init(position: 42),
                text: .init(highlight: "Excerpt")
            ).json,
            [
                "href": "http://locator",
                "type": "text/html",
                "title": "My Locator",
                "locations": [
                    "position": 42
                ],
                "text": [
                    "highlight": "Excerpt"
                ]
            ]
        )
    }
    
}


class LocationTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Locations(json: [
                "position": 42
            ]),
            Locations(
                position: 42
            )
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? Locations(json: [
                "fragment": "frag34",
                "progression": 0.74,
                "position": 42
            ]),
            Locations(
                fragment: "frag34",
                progression: 0.74,
                position: 42
            )
        )
    }
    
    func testParseEmptyJSON() {
        XCTAssertEqual(
            try Locations(json: [:]),
            Locations()
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Locations(json: ""))
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            Locations(
                position: 42
            ).json as Any,
            [
                "position": 42
            ]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            Locations(
                fragment: "frag34",
                progression: 0.74,
                position: 42
            ).json as Any,
            [
                "fragment": "frag34",
                "progression": 0.74,
                "position": 42
            ]
        )
    }
    
}


class LocatorTextTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? LocatorText(json: [
                "after": "Text after"
            ]),
            LocatorText(
                after: "Text after"
            )
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? LocatorText(json: [
                "after": "Text after",
                "before": "Text before",
                "highlight": "Highlighted text"
            ]),
            LocatorText(
                after: "Text after",
                before: "Text before",
                highlight: "Highlighted text"
            )
        )
    }
    
    func testParseEmptyJSON() {
        XCTAssertEqual(
            try LocatorText(json: [:]),
            LocatorText()
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try LocatorText(json: ""))
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            LocatorText(
                after: "Text after"
            ).json as Any,
            [
                "after": "Text after"
            ]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            LocatorText(
                after: "Text after",
                before: "Text before",
                highlight: "Highlighted text"
            ).json as Any,
            [
                "after": "Text after",
                "before": "Text before",
                "highlight": "Highlighted text"
            ]
        )
    }
    
}
