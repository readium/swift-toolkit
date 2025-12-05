//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class DOMRangeTests: XCTestCase {
    func testParseMinimalDOMRangeJSON() {
        XCTAssertEqual(
            try? DOMRange(json: ["start": ["cssSelector": "p", "textNodeIndex": 4] as [String: Any]]),
            DOMRange(start: .init(cssSelector: "p", textNodeIndex: 4))
        )
    }

    func testParseFullDOMRangeJSON() {
        XCTAssertEqual(
            try? DOMRange(json: [
                "start": [
                    "cssSelector": "p",
                    "textNodeIndex": 4,
                ] as [String: Any],
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
        XCTAssertThrowsError(try DOMRange(json: ["end": ["cssSelector": "p", "textNodeIndex": 4] as [String: Any]]))
    }

    func testParseDOMRangeAllowsNil() {
        XCTAssertNil(try DOMRange(json: nil))
    }

    func testGetMinimalDOMRangeJSON() {
        AssertJSONEqual(
            DOMRange(start: .init(cssSelector: "p", textNodeIndex: 4)).json,
            ["start": ["cssSelector": "p", "textNodeIndex": 4] as [String: Any]]
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
                    "textNodeIndex": 4,
                ] as [String: Any],
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
            ] as [String: Any]),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 4)
        )
    }

    func testParseFullPointJSON() {
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 4,
                "charOffset": 32,
            ] as [String: Any]),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 4, charOffset: 32)
        )
    }

    func testParseLegacyPointJSON() {
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 4,
                "offset": 32,
            ] as [String: Any]),
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
            ] as [String: Any]),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 1)
        )
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 0,
            ] as [String: Any]),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 0)
        )
        XCTAssertNil(try? DOMRange.Point(json: [
            "cssSelector": "p",
            "textNodeIndex": -1,
        ] as [String: Any]))
    }

    func testParsePointJSONRequiresPositiveCharOffset() {
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 1,
                "charOffset": 1,
            ] as [String: Any]),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 1, charOffset: 1)
        )
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 1,
                "charOffset": 0,
            ] as [String: Any]),
            DOMRange.Point(cssSelector: "p", textNodeIndex: 1, charOffset: 0)
        )
        XCTAssertEqual(
            try? DOMRange.Point(json: [
                "cssSelector": "p",
                "textNodeIndex": 1,
                "charOffset": -1,
            ] as [String: Any]),
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
                "textNodeIndex": 4,
            ] as [String: Any]
        )
    }

    func testGetFullPointJSON() {
        AssertJSONEqual(
            DOMRange.Point(cssSelector: "p", textNodeIndex: 4, charOffset: 32).json,
            [
                "cssSelector": "p",
                "textNodeIndex": 4,
                "charOffset": 32,
            ] as [String: Any]
        )
    }
}
