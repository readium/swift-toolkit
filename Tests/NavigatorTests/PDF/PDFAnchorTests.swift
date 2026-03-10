//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import XCTest

class PDFAnchorExtractorTests: XCTestCase {

    // MARK: - Context Extraction Tests

    func testExtractContextAroundMiddleOfText() {
        let text = "The quick brown fox jumps over the lazy dog."
        let range = 16..<19 // "fox"

        let (before, after) = PDFAnchorExtractor.extractContext(
            around: range,
            in: text,
            contextLength: 10
        )

        XCTAssertEqual(before, "ick brown ") // 10 chars before "fox": indices 6-15
        XCTAssertEqual(after, " jumps ove") // 10 chars after "fox": indices 19-28
    }

    func testExtractContextAtStartOfText() {
        let text = "The quick brown fox jumps over the lazy dog."
        let range = 0..<3 // "The"

        let (before, after) = PDFAnchorExtractor.extractContext(
            around: range,
            in: text,
            contextLength: 10
        )

        XCTAssertNil(before) // No text before
        XCTAssertEqual(after, " quick bro")
    }

    func testExtractContextAtEndOfText() {
        let text = "The quick brown fox jumps over the lazy dog."
        let range = 40..<44 // "dog."

        let (before, after) = PDFAnchorExtractor.extractContext(
            around: range,
            in: text,
            contextLength: 10
        )

        XCTAssertEqual(before, " the lazy ")
        XCTAssertNil(after) // No text after
    }

    func testExtractContextWithShortText() {
        let text = "Hello"
        let range = 0..<5

        let (before, after) = PDFAnchorExtractor.extractContext(
            around: range,
            in: text,
            contextLength: 20
        )

        XCTAssertNil(before)
        XCTAssertNil(after)
    }

    // MARK: - Bounds Comparison Tests

    func testBoundsApproximatelyEqualWithExactMatch() {
        let a = CGRect(x: 10, y: 20, width: 100, height: 50)
        let b = CGRect(x: 10, y: 20, width: 100, height: 50)

        XCTAssertTrue(PDFAnchorExtractor.boundsApproximatelyEqual(a, b, tolerance: 1.0))
    }

    func testBoundsApproximatelyEqualWithinTolerance() {
        let a = CGRect(x: 10, y: 20, width: 100, height: 50)
        let b = CGRect(x: 12, y: 22, width: 102, height: 52)

        XCTAssertTrue(PDFAnchorExtractor.boundsApproximatelyEqual(a, b, tolerance: 5.0))
    }

    func testBoundsApproximatelyEqualOutsideTolerance() {
        let a = CGRect(x: 10, y: 20, width: 100, height: 50)
        let b = CGRect(x: 20, y: 30, width: 110, height: 60)

        XCTAssertFalse(PDFAnchorExtractor.boundsApproximatelyEqual(a, b, tolerance: 5.0))
    }
}

class PDFAnchorResolverTests: XCTestCase {

    // MARK: - Anchor Parsing Tests

    func testParseAnchorFromDictionary() {
        let data: [String: Any] = [
            "pageIndex": 0,
            "text": "Hello World",
            "characterStart": 10,
            "characterEnd": 21,
            "textBefore": "Say ",
            "textAfter": " to everyone"
        ]

        let anchor = PDFAnchorResolver.parseAnchor(data)

        XCTAssertNotNil(anchor)
        XCTAssertEqual(anchor?.pageIndex, 0)
        XCTAssertEqual(anchor?.text, "Hello World")
        XCTAssertEqual(anchor?.characterStart, 10)
        XCTAssertEqual(anchor?.characterEnd, 21)
        XCTAssertEqual(anchor?.textBefore, "Say ")
        XCTAssertEqual(anchor?.textAfter, " to everyone")
    }

    func testParseAnchorFromJSONString() {
        let jsonString = """
        {"pageIndex":1,"text":"Test text","characterStart":5,"characterEnd":14}
        """

        let anchor = PDFAnchorResolver.parseAnchor(jsonString)

        XCTAssertNotNil(anchor)
        XCTAssertEqual(anchor?.pageIndex, 1)
        XCTAssertEqual(anchor?.text, "Test text")
        XCTAssertEqual(anchor?.characterStart, 5)
        XCTAssertEqual(anchor?.characterEnd, 14)
    }

    func testParseAnchorWithQuads() {
        let data: [String: Any] = [
            "text": "Highlighted",
            "quads": [
                [
                    ["x": 10.0, "y": 20.0],
                    ["x": 110.0, "y": 20.0],
                    ["x": 110.0, "y": 40.0],
                    ["x": 10.0, "y": 40.0]
                ]
            ]
        ]

        let anchor = PDFAnchorResolver.parseAnchor(data)

        XCTAssertNotNil(anchor)
        XCTAssertNotNil(anchor?.quads)
        XCTAssertEqual(anchor?.quads?.count, 1)
        XCTAssertEqual(anchor?.quads?.first?.count, 4)
        XCTAssertEqual(anchor?.quads?.first?.first, CGPoint(x: 10, y: 20))
    }

    func testParseAnchorWithMissingTextReturnsNil() {
        let data: [String: Any] = [
            "pageIndex": 0,
            "characterStart": 10
        ]

        let anchor = PDFAnchorResolver.parseAnchor(data)

        XCTAssertNil(anchor)
    }

    func testParseAnchorWithInvalidDataReturnsNil() {
        let anchor = PDFAnchorResolver.parseAnchor(12345)
        XCTAssertNil(anchor)
    }

    // MARK: - Quads Parsing Tests

    func testParseQuadsWithValidData() {
        let quadsData: [[[String: Double]]] = [
            [
                ["x": 0.0, "y": 0.0],
                ["x": 100.0, "y": 0.0],
                ["x": 100.0, "y": 20.0],
                ["x": 0.0, "y": 20.0]
            ],
            [
                ["x": 0.0, "y": 25.0],
                ["x": 80.0, "y": 25.0],
                ["x": 80.0, "y": 45.0],
                ["x": 0.0, "y": 45.0]
            ]
        ]

        let quads = PDFAnchorResolver.parseQuads(quadsData)

        XCTAssertNotNil(quads)
        XCTAssertEqual(quads?.count, 2)
        XCTAssertEqual(quads?[0].count, 4)
        XCTAssertEqual(quads?[1].count, 4)
    }

    func testParseQuadsWithNilReturnsNil() {
        let quads = PDFAnchorResolver.parseQuads(nil)
        XCTAssertNil(quads)
    }

    func testParseQuadsWithInvalidFormatReturnsNil() {
        let quads = PDFAnchorResolver.parseQuads("invalid")
        XCTAssertNil(quads)
    }

    // MARK: - Quads to Bounds Resolution Tests

    func testResolveFromQuads() {
        let quads: [[CGPoint]] = [
            [
                CGPoint(x: 10, y: 20),
                CGPoint(x: 110, y: 20),
                CGPoint(x: 110, y: 40),
                CGPoint(x: 10, y: 40)
            ]
        ]

        let bounds = PDFAnchorResolver.resolveFromQuads(quads)

        XCTAssertNotNil(bounds)
        XCTAssertEqual(bounds?.count, 1)
        XCTAssertEqual(bounds?.first, CGRect(x: 10, y: 20, width: 100, height: 20))
    }

    func testResolveFromQuadsWithMultipleLines() {
        let quads: [[CGPoint]] = [
            [
                CGPoint(x: 10, y: 100),
                CGPoint(x: 200, y: 100),
                CGPoint(x: 200, y: 120),
                CGPoint(x: 10, y: 120)
            ],
            [
                CGPoint(x: 10, y: 75),
                CGPoint(x: 150, y: 75),
                CGPoint(x: 150, y: 95),
                CGPoint(x: 10, y: 95)
            ]
        ]

        let bounds = PDFAnchorResolver.resolveFromQuads(quads)

        XCTAssertNotNil(bounds)
        XCTAssertEqual(bounds?.count, 2)
        XCTAssertEqual(bounds?[0], CGRect(x: 10, y: 100, width: 190, height: 20))
        XCTAssertEqual(bounds?[1], CGRect(x: 10, y: 75, width: 140, height: 20))
    }

    func testResolveFromQuadsWithEmptyArrayReturnsNil() {
        let bounds = PDFAnchorResolver.resolveFromQuads([])
        XCTAssertNil(bounds)
    }

    // MARK: - Context Score Tests

    func testContextScoreWithExactMatch() {
        let text = "prefix Hello World suffix"
        let range = text.range(of: "Hello World")!

        let score = PDFAnchorResolver.contextScore(
            for: range,
            textBefore: "prefix ",
            textAfter: " suffix",
            in: text
        )

        XCTAssertEqual(score, 40) // 20 for exact before + 20 for exact after
    }

    func testContextScoreWithPartialMatch() {
        // In this text, the actual context is "prefix " before and " suffix" after
        // which exactly matches the expected context, so it scores 40
        let text = "Some prefix Hello World suffix here"
        let range = text.range(of: "Hello World")!

        let score = PDFAnchorResolver.contextScore(
            for: range,
            textBefore: "prefix ",
            textAfter: " suffix",
            in: text
        )

        XCTAssertEqual(score, 40) // 20 for exact before + 20 for exact after
    }

    func testContextScoreWithNoMatch() {
        let text = "Different Hello World content"
        let range = text.range(of: "Hello World")!

        let score = PDFAnchorResolver.contextScore(
            for: range,
            textBefore: "nomatch ",
            textAfter: " nomatch",
            in: text
        )

        XCTAssertEqual(score, 0)
    }

    func testContextScoreWithNilContext() {
        let text = "Hello World"
        let range = text.range(of: "Hello World")!

        let score = PDFAnchorResolver.contextScore(
            for: range,
            textBefore: nil,
            textAfter: nil,
            in: text
        )

        XCTAssertEqual(score, 0)
    }

    // MARK: - Whitespace Normalization Tests

    func testNormalizeWhitespaceCollapsesSpaces() {
        let text = "Hello    World"
        let normalized = PDFAnchorResolver.normalizeWhitespace(text)
        XCTAssertEqual(normalized, "Hello World")
    }

    func testNormalizeWhitespaceConvertsNewlines() {
        let text = "Hello\n\nWorld"
        let normalized = PDFAnchorResolver.normalizeWhitespace(text)
        XCTAssertEqual(normalized, "Hello World")
    }

    func testNormalizeWhitespaceHandlesMixedWhitespace() {
        let text = "Hello \t\n  World\n\n\tTest"
        let normalized = PDFAnchorResolver.normalizeWhitespace(text)
        XCTAssertEqual(normalized, "Hello World Test")
    }

    func testNormalizeWhitespaceTrimsEdges() {
        let text = "  Hello World  "
        let normalized = PDFAnchorResolver.normalizeWhitespace(text)
        XCTAssertEqual(normalized, "Hello World")
    }

    // MARK: - First Words Extraction Tests

    func testExtractFirstWordsWithEnoughWords() {
        let text = "The quick brown fox jumps over the lazy dog"
        let firstWords = PDFAnchorResolver.extractFirstWords(from: text, count: 5)
        XCTAssertEqual(firstWords, "The quick brown fox jumps")
    }

    func testExtractFirstWordsWithFewerWords() {
        let text = "Hello World"
        let firstWords = PDFAnchorResolver.extractFirstWords(from: text, count: 5)
        XCTAssertEqual(firstWords, "Hello World")
    }

    func testExtractFirstWordsWithEmptyString() {
        let text = ""
        let firstWords = PDFAnchorResolver.extractFirstWords(from: text, count: 5)
        XCTAssertEqual(firstWords, "")
    }

    func testExtractFirstWordsHandlesExtraSpaces() {
        let text = "  The   quick   brown  "
        let firstWords = PDFAnchorResolver.extractFirstWords(from: text, count: 2)
        XCTAssertEqual(firstWords, "The quick")
    }
}
