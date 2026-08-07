//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumNavigator
import ReadiumShared
import Testing

struct PublicationSpeechSynthesizerUtteranceTests {
    /// A sentence hyphenated across two PDF pages: "particu-" / "larly".
    private let utterance = PublicationSpeechSynthesizer.Utterance(
        parts: [
            .init(text: "There is a particu", locator: locator(page: 1, highlight: "There is a particu-")),
            .init(text: "larly comfortable hotel.", locator: locator(page: 2, highlight: "larly comfortable hotel.")),
        ],
        language: nil
    )

    @Test func textAndLocatorAreDerivedFromParts() {
        #expect(utterance.text == "There is a particularly comfortable hotel.")
        #expect(utterance.locator.locations.fragments == ["page=1"])
    }

    @Test func spokenRangeInFirstPartUsesItsLocator() throws {
        let range = try #require(utterance.text.range(of: "There"))
        let locator = utterance.locator(forSpokenRange: range)
        #expect(locator.locations.fragments == ["page=1"])
        #expect(locator.text.highlight == "There")
    }

    @Test func spokenRangeInSecondPartTurnsToItsPage() throws {
        let range = try #require(utterance.text.range(of: "comfortable"))
        let locator = utterance.locator(forSpokenRange: range)
        #expect(locator.locations.fragments == ["page=2"])
        #expect(locator.text.highlight == "comfortable")
    }

    @Test func spaceJoinedContinuationShiftsIntoTheHighlight() throws {
        // The continuation's spoken text carries a joining space which is not
        // part of the on-page highlight.
        let utterance = PublicationSpeechSynthesizer.Utterance(
            parts: [
                .init(text: "The hungry cat sat on", locator: locator(page: 1, highlight: "The hungry cat sat on")),
                .init(text: " the mat with style.", locator: locator(page: 2, highlight: "the mat with style.")),
            ],
            language: nil
        )
        let range = try #require(utterance.text.range(of: "mat"))
        let result = utterance.locator(forSpokenRange: range)
        #expect(result.locations.fragments == ["page=2"])
        #expect(result.text.highlight == "mat")
    }

    @Test func rangeSpanningTheSeamClampsIntoTheFirstPart() throws {
        // "particularly" straddles the two parts; the locator maps to the
        // part containing the start of the range, clamped to its on-page
        // highlight (which keeps the hyphen).
        let range = try #require(utterance.text.range(of: "particularly"))
        let result = utterance.locator(forSpokenRange: range)
        #expect(result.locations.fragments == ["page=1"])
        #expect(result.text.highlight == "particu-")
    }

    @Test func singlePartIsTheDegenerateCase() {
        let utterance = PublicationSpeechSynthesizer.Utterance(
            parts: [.init(text: "A sentence.", locator: locator(page: 1, highlight: "A sentence."))],
            language: nil
        )
        #expect(utterance.text == "A sentence.")
        #expect(utterance.parts.count == 1)
    }
}

private func locator(page: Int, highlight: String) -> Locator {
    Locator(href: AnyURL(string: "book.pdf")!, mediaType: .pdf).copy(
        locations: { $0.fragments = ["page=\(page)"] },
        text: { $0 = Locator.Text(highlight: highlight) }
    )
}
