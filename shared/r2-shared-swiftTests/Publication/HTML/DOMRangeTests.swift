//
//  DOMRangeTests.swift
//  r2-shared-swift
//
//  Created by Mickaël on 25/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class DOMRangeTests: XCTestCase {

    func testParseMinimalDOMRangeJSON() {
        XCTAssertEqual(
            try? DOMRange(json: ["start": ["cssSelector": "p", "textNodeIndex": 4]]),
            DOMRange(start: .init(cssSelector: "p", textNodeIndex: 4))
        )
    }
    
    func testParseFullDOMRangeJSON() {
        XCTAssertEqual(
            try? DOMRange(json: [
                "start": [
                    "cssSelector": "p",
                    "textNodeIndex": 4
                ],
                "end": [
                    "cssSelector": "a",
                    "textNodeIndex": 2
                ]
            ]),
            DOMRange(
                start: .init(cssSelector: "p", textNodeIndex: 4),
                end: .init(cssSelector: "a", textNodeIndex: 2)
            )
        )
    }

    func testParseDOMRangeJSONRequiresStart() {
        XCTAssertThrowsError(try DOMRange(json: ["end": ["cssSelector": "p", "textNodeIndex": 4]]))
    }
    
    func testParseDOMRangeAllowsNil() {
        XCTAssertNil(try DOMRange(json: nil))
    }

    func testGetMinimalDOMRangeJSON() {
        AssertJSONEqual(
            DOMRange(start: .init(cssSelector: "p", textNodeIndex: 4)).json,
            ["start": ["cssSelector": "p", "textNodeIndex": 4]]
        )
    }
    
    func testGetFullDOMRangeJSON() {
        AssertJSONEqual(
            DOMRange(
                start: .init(cssSelector: "p", textNodeIndex: 4),
                end: .init(cssSelector: "a", textNodeIndex: 2)
            ).json,
            [
                "start": [
                    "cssSelector": "p",
                    "textNodeIndex": 4
                ],
                "end": [
                    "cssSelector": "a",
                    "textNodeIndex": 2
                ]
            ]
        )
    }

    func testParseMinimalPointJSON() {
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 4
            ]),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 4)
        )
    }
    
    func testParseFullPointJSON() {
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 4,
                "charOffset": 32
            ]),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 4, charOffset: 32)
        )
    }

    func testParseLegacyPointJSON() {
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 4,
                "offset": 32
            ]),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 4, charOffset: 32)
        )
    }

    func testParseInvalidPointJSON() {
        XCTAssertThrowsError(try DOMRange.Point(json: ""))
    }
    
    func testParsePointJSONRequiresCSSSelector() {
        XCTAssertThrowsError(try DOMRange.Point(json: [
            "textNodeIndex": 4
        ]))
    }
    
    func testParsePointJSONRequiresTextNodeIndex() {
        XCTAssertThrowsError(try DOMRange.Point(json: [
            "cssSelector": "p"
        ]))
    }
    
    func testParsePointJSONRequiresPositiveTextNodeIndex() {
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 1
            ]),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 1)
        )
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 0
            ]),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 0)
        )
        XCTAssertNil(try? DOMRange.Point(json: [
            "cssSelector": "p",
            "textNodeIndex": -1
        ]))
    }
    
    func testParsePointJSONRequiresPositiveCharOffset() {
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 1,
                "charOffset": 1
            ]),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 1, charOffset: 1)
        )
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 1,
                "charOffset": 0
            ]),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 1, charOffset: 0)
        )
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 1,
                "charOffset": -1
            ]),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 1, charOffset: nil)
        )
    }
    
    func testParsePointAllowsNil() {
        XCTAssertNil(try DOMRange.Point(json: nil))
    }

    func testGetMinimalPointJSON() {
        AssertJSONEqual(
            DOMRange.Point(cssSelector: "p", textNodeIndex: 4).json,
            [
                "cssSelector": "p",
                "textNodeIndex": 4
            ]
        )
    }
    
    func testGetFullPointJSON() {
        AssertJSONEqual(
            DOMRange.Point(cssSelector: "p", textNodeIndex: 4, charOffset: 32).json,
            [
                "cssSelector": "p",
                "textNodeIndex": 4,
                "charOffset": 32
            ]
        )
    }
    
}
