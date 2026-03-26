//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class DOMRangeTests: XCTestCase {
    func testParseMinimalDOMRangeJSON() {
        XCTAssertEqual(
            try? DOMRange(json: ["start": ["cssSelector": "p", "textNodeIndex": 4] as JSONValue]),
            DOMRange(start: .init(cssSelector: "p", textNodeIndex: 4))
        )
    }

    func testParseFullDOMRangeJSON() {
        XCTAssertEqual(
            try? DOMRange(json: [
                "start": [
                    "cssSelector": "p",
                    "textNodeIndex": 4,
                ] as JSONValue,
                "end": [
                    "cssSelector": "a",
                    "textNodeIndex": 2,
                ],
            ]),
            DOMRange(
                start: .init(cssSelector: "p", textNodeIndex: 4),
                end: .init(cssSelector: "a", textNodeIndex: 2)
            )
        )
    }

    func testParseDOMRangeJSONRequiresStart() {
        XCTAssertThrowsError(try DOMRange(json: ["end": ["cssSelector": "p", "textNodeIndex": 4] as JSONValue]))
    }

    func testParseDOMRangeAllowsNil() {
        XCTAssertNil(try DOMRange(json: nil as JSONValue?))
    }

    func testGetMinimalDOMRangeJSON() {
        XCTAssertEqual(
            DOMRange(start: .init(cssSelector: "p", textNodeIndex: 4)).jsonObject,
            ["start": ["cssSelector": "p", "textNodeIndex": 4] as JSONValue]
        )
    }

    func testGetFullDOMRangeJSON() {
        XCTAssertEqual(
            DOMRange(
                start: .init(cssSelector: "p", textNodeIndex: 4),
                end: .init(cssSelector: "a", textNodeIndex: 2)
            ).jsonObject,
            [
                "start": [
                    "cssSelector": "p",
                    "textNodeIndex": 4,
                ] as JSONValue,
                "end": [
                    "cssSelector": "a",
                    "textNodeIndex": 2,
                ],
            ]
        )
    }

    func testParseMinimalPointJSON() {
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 4,
            ] as JSONValue),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 4)
        )
    }

    func testParseFullPointJSON() {
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 4,
                "charOffset": 32,
            ] as JSONValue),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 4, charOffset: 32)
        )
    }

    func testParseLegacyPointJSON() {
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 4,
                "offset": 32,
            ] as JSONValue),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 4, charOffset: 32)
        )
    }

    func testParseInvalidPointJSON() {
        XCTAssertThrowsError(try DOMRange.Point(json: ""))
    }

    func testParsePointJSONRequiresCSSSelector() {
        XCTAssertThrowsError(try DOMRange.Point(json: [
            "textNodeIndex": 4,
        ]))
    }

    func testParsePointJSONRequiresTextNodeIndex() {
        XCTAssertThrowsError(try DOMRange.Point(json: [
            "cssSelector": "p",
        ]))
    }

    func testParsePointJSONRequiresPositiveTextNodeIndex() {
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 1,
            ] as JSONValue),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 1)
        )
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 0,
            ] as JSONValue),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 0)
        )
        XCTAssertNil(try? DOMRange.Point(json: [
            "cssSelector": "p",
            "textNodeIndex": -1,
        ] as JSONValue))
    }

    func testParsePointJSONRequiresPositiveCharOffset() {
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 1,
                "charOffset": 1,
            ] as JSONValue),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 1, charOffset: 1)
        )
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 1,
                "charOffset": 0,
            ] as JSONValue),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 1, charOffset: 0)
        )
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 1,
                "charOffset": -1,
            ] as JSONValue),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 1, charOffset: nil)
        )
    }

    func testParsePointAllowsNil() {
        XCTAssertNil(try DOMRange.Point(json: nil as JSONValue?))
    }

    func testGetMinimalPointJSON() {
        XCTAssertEqual(
            DOMRange.Point(cssSelector: "p", textNodeIndex: 4).jsonObject,
            [
                "cssSelector": "p",
                "textNodeIndex": 4,
            ] as [String: JSONValue]
        )
    }

    func testGetFullPointJSON() {
        XCTAssertEqual(
            DOMRange.Point(cssSelector: "p", textNodeIndex: 4, charOffset: 32).jsonObject,
            [
                "cssSelector": "p",
                "textNodeIndex": 4,
                "charOffset": 32,
            ] as [String: JSONValue]
        )
    }
}
