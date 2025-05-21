//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

@available(iOS 12.0, *)
class TextTokenizerTests: XCTestCase {
    // MARK: - NL

    func testNLTokenizeEmptyText() {
        let tokenizer = makeNLTextTokenizer(unit: .word)
        XCTAssertEqual(try tokenizer(""), [])
    }

    func testNLTokenizeByWords() {
        let tokenizer = makeNLTextTokenizer(unit: .word)
        let text = "He said: \n\"What?\""
        XCTAssertEqual(
            try tokenizer(text).map { String(text[$0]) },
            ["He", "said", "What"]
        )
    }

    func testNLTokenizeBySentences() {
        let tokenizer = makeNLTextTokenizer(unit: .sentence)
        let text =
            """
                Mr. Bougee said, looking above: "and what is the use of a book?". So she was considering (as well as she could), whether making a daisy-chain would be worth the trouble
                In the end, she went ahead.
            """
        XCTAssertEqual(
            try tokenizer(text).map { String(text[$0]) },
            [
                "Mr. Bougee said, looking above: \"and what is the use of a book?\".",
                "So she was considering (as well as she could), whether making a daisy-chain would be worth the trouble",
                "In the end, she went ahead.",
            ]
        )
    }

    func testNLTokenizeByParagraphs() {
        let tokenizer = makeNLTextTokenizer(unit: .paragraph)
        let text =
            """
                Oh dear, what nonsense I'm talking! Really?

                Just then her head struck against the roof of the hall: in fact she was now more than nine feet high, and she at once took up the little golden key and hurried off to the garden door.
                Poor Alice! It was as much as she could do, lying down on one side, to look through into the garden with one eye; but to get through was more hopeless than ever: she sat down and began to cry again.
            """
        XCTAssertEqual(
            try tokenizer(text).map { String(text[$0]) },
            [
                "Oh dear, what nonsense I'm talking! Really?",
                "Just then her head struck against the roof of the hall: in fact she was now more than nine feet high, and she at once took up the little golden key and hurried off to the garden door.",
                "Poor Alice! It was as much as she could do, lying down on one side, to look through into the garden with one eye; but to get through was more hopeless than ever: she sat down and began to cry again.",
            ]
        )
    }

    // MARK: - NS

    func testNSTokenizeEmptyText() {
        let tokenizer = makeNSTextTokenizer(unit: .word)
        XCTAssertEqual(try tokenizer(""), [])
    }

    func testNSTokenizeByWords() {
        let tokenizer = makeNSTextTokenizer(unit: .word)
        let text = "He said: \n\"What?\""
        XCTAssertEqual(
            try tokenizer(text).map { String(text[$0]) },
            ["He", "said", "What"]
        )
    }

    func testNSTokenizeBySentences() {
        let tokenizer = makeNSTextTokenizer(unit: .sentence)
        let text =
            """
                Mr. Bougee said, looking above: "and what is the use of a book?". So she was considering (as well as she could), whether making a daisy-chain would be worth the trouble
                In the end, she went ahead.
            """
        XCTAssertEqual(
            try tokenizer(text).map { String(text[$0]) },
            [
                "Mr. Bougee said, looking above: \"and what is the use of a book?\".",
                "So she was considering (as well as she could), whether making a daisy-chain would be worth the trouble",
                "In the end, she went ahead.",
            ]
        )
    }

    func testNSTokenizeByParagraphs() {
        let tokenizer = makeNSTextTokenizer(unit: .paragraph)
        let text =
            """
                Oh dear, what nonsense I'm talking! Really?

                Just then her head struck against the roof of the hall: in fact she was now more than nine feet high, and she at once took up the little golden key and hurried off to the garden door.
                Poor Alice! It was as much as she could do, lying down on one side, to look through into the garden with one eye; but to get through was more hopeless than ever: she sat down and began to cry again.
            """
        XCTAssertEqual(
            try tokenizer(text).map { String(text[$0]) },
            [
                "Oh dear, what nonsense I'm talking! Really?",
                "Just then her head struck against the roof of the hall: in fact she was now more than nine feet high, and she at once took up the little golden key and hurried off to the garden door.",
                "Poor Alice! It was as much as she could do, lying down on one side, to look through into the garden with one eye; but to get through was more hopeless than ever: she sat down and began to cry again.",
            ]
        )
    }

    // MARK: - Simple

    func testSimpleTokenizeEmptyText() {
        let tokenizer = makeSimpleTextTokenizer(unit: .word)
        XCTAssertEqual(try tokenizer(""), [])
    }

    func testSimpleTokenizeByWords() {
        let tokenizer = makeSimpleTextTokenizer(unit: .word)
        let text = "He said: \n\"What?\""
        XCTAssertEqual(
            try tokenizer(text).map { String(text[$0]) },
            ["He", "said", "What"]
        )
    }

    func testSimpleTokenizeBySentences() {
        let tokenizer = makeSimpleTextTokenizer(unit: .sentence)
        let text =
            """
                Mr. Bougee said, looking above: "and what is the use of a book?". So she was considering (as well as she could), whether making a daisy-chain would be worth the trouble
                In the end, she went ahead.
            """
        XCTAssertEqual(
            try tokenizer(text).map { String(text[$0]) },
            [
                "Mr.",
                "Bougee said, looking above: \"and what is the use of a book?\".",
                "So she was considering (as well as she could), whether making a daisy-chain would be worth the trouble",
                "In the end, she went ahead.",
            ]
        )
    }

    func testSimpleTokenizeByParagraphs() {
        let tokenizer = makeSimpleTextTokenizer(unit: .paragraph)
        let text =
            """
                Oh dear, what nonsense I'm talking! Really?

                Just then her head struck against the roof of the hall: in fact she was now more than nine feet high, and she at once took up the little golden key and hurried off to the garden door.
                Poor Alice! It was as much as she could do, lying down on one side, to look through into the garden with one eye; but to get through was more hopeless than ever: she sat down and began to cry again.
            """
        XCTAssertEqual(
            try tokenizer(text).map { String(text[$0]) },
            [
                "Oh dear, what nonsense I'm talking! Really?",
                "Just then her head struck against the roof of the hall: in fact she was now more than nine feet high, and she at once took up the little golden key and hurried off to the garden door.",
                "Poor Alice! It was as much as she could do, lying down on one side, to look through into the garden with one eye; but to get through was more hopeless than ever: she sat down and began to cry again.",
            ]
        )
    }
}
