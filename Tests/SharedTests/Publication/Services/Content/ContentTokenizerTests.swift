//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

struct ContentTokenizerTests {
    private let tokenizer = makeTextContentTokenizer(
        defaultLanguage: Language(code: .bcp47("en")),
        textTokenizerFactory: { language in
            makeDefaultTextTokenizer(unit: .sentence, language: language)
        }
    )

    @Test func sentenceAlignedElementPassesThroughUntouched() throws {
        // An element produced by the `SentenceContentIterator`: already one
        // sentence, with an on-page highlight differing from the spoken text.
        let locator = Locator(href: "book.pdf", mediaType: .pdf).copy(text: {
            $0 = Locator.Text(highlight: "There is a particu-")
        })
        let element = TextContentElement(
            locator: locator,
            role: .body,
            segments: [
                TextContentElement.Segment(locator: locator, text: "There is a particu"),
                TextContentElement.Segment(
                    locator: locator,
                    text: "larly comfortable hotel.",
                    attributes: [ContentAttribute(key: .continued, value: ContentContinuationJoiner.direct)]
                ),
            ],
            attributes: [ContentAttribute(key: .sentenceAligned, value: true)]
        )

        let result = try tokenizer(element)
        try #require(result.count == 1)
        let passedThrough = try #require(result[0] as? TextContentElement)
        #expect(passedThrough == element)
        // The on-page highlight is preserved.
        #expect(passedThrough.segments[0].locator.text.highlight == "There is a particu-")
    }

    @Test func reflowableElementIsStillTokenizedIntoSentences() throws {
        let locator = Locator(href: "chapter.xhtml", mediaType: .xhtml)
        let element = TextContentElement(
            locator: locator,
            role: .body,
            segments: [
                TextContentElement.Segment(locator: locator, text: "One sentence here. Two sentences there."),
            ]
        )

        let result = try tokenizer(element)
        try #require(result.count == 1)
        let tokenized = try #require(result[0] as? TextContentElement)
        try #require(tokenized.segments.count == 2)

        #expect(tokenized.segments[0].text == "One sentence here.")
        #expect(tokenized.segments[0].locator.text.highlight == "One sentence here.")
        #expect(tokenized.segments[0].locator.text.before == nil)
        #expect(tokenized.segments[0].locator.text.after == " Two sentences there.")

        #expect(tokenized.segments[1].text == "Two sentences there.")
        #expect(tokenized.segments[1].locator.text.highlight == "Two sentences there.")
        #expect(tokenized.segments[1].locator.text.before == "One sentence here. ")
        #expect(tokenized.segments[1].locator.text.after == nil)
    }
}
