//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
@testable import R2Shared

import NaturalLanguage

@available(iOS 12.0, *)
class NSTokenizerTests: XCTestCase {

    func testTokenizeEmptyText() {
        let tokenizer = NSTokenizer(unit: .word)
        XCTAssertEqual(try tokenizer.tokenize(text: ""), [])
    }

    func testTokenizeByWords() {
        let tokenizer = NSTokenizer(unit: .word)
        let text = "He said: \n\"What?\""
        XCTAssertEqual(
            try tokenizer.tokenize(text: text).map { String(text[$0]) },
            ["He", "said", "What"]
        )
    }

    func testTokenizeBySentences() {
        let tokenizer = NSTokenizer(unit: .sentence)
        let text =
            """
                Mr. Bougee said, looking above: "and what is the use of a book?". So she was considering (as well as she could), whether making a daisy-chain would be worth the trouble
                In the end, she went ahead.
            """
        XCTAssertEqual(
            try tokenizer.tokenize(text: text).map { String(text[$0]) },
            [
                "Mr. Bougee said, looking above: \"and what is the use of a book?\".",
                "So she was considering (as well as she could), whether making a daisy-chain would be worth the trouble",
                "In the end, she went ahead."
            ]
        )
    }

    func testTokenizeByParagraphs() {
        let tokenizer = NSTokenizer(unit: .paragraph)
        let text =
            """
                Oh dear, what nonsense I'm talking! Really?

                Just then her head struck against the roof of the hall: in fact she was now more than nine feet high, and she at once took up the little golden key and hurried off to the garden door.
                Poor Alice! It was as much as she could do, lying down on one side, to look through into the garden with one eye; but to get through was more hopeless than ever: she sat down and began to cry again.
            """
        XCTAssertEqual(
            try tokenizer.tokenize(text: text).map { String(text[$0]) },
            [
                "Oh dear, what nonsense I'm talking! Really?",
                "Just then her head struck against the roof of the hall: in fact she was now more than nine feet high, and she at once took up the little golden key and hurried off to the garden door.",
                "Poor Alice! It was as much as she could do, lying down on one side, to look through into the garden with one eye; but to get through was more hopeless than ever: she sat down and began to cry again."
            ]
        )
    }
}
