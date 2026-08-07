//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum SentenceContentIteratorTests {
    struct PDFPages {
        @Test func lineBreaksWithinAPageAreResegmented() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "First sentence. There is a particu-\nlarly comfortable hotel in\nthis town. Done here."),
            ])

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "First sentence.")
            #expect(first.attribute(.sentenceAligned) == true)

            let second = try #require(try await iter.next() as? TextContentElement)
            #expect(second.text == "There is a particularly comfortable hotel in this town.")
            let segments = second.segments
            try #require(segments.count == 3)

            // Part 1 drops the hyphen in its text but keeps the on-page form
            // in the highlight.
            #expect(segments[0].text == "There is a particu")
            #expect(segments[0].locator.text.highlight == "There is a particu-")
            #expect(segments[0].attribute(.continued) == nil)

            // Part 2 is joined directly (de-hyphenation).
            #expect(segments[1].text == "larly comfortable hotel in")
            #expect(segments[1].attribute(.continued) == ContentContinuationJoiner.direct)

            // Part 3 carries its joining space.
            #expect(segments[2].text == " this town.")
            #expect(segments[2].locator.text.highlight == "this town.")
            #expect(segments[2].attribute(.continued) == ContentContinuationJoiner.space)

            let third = try #require(try await iter.next() as? TextContentElement)
            #expect(third.text == "Done here.")

            #expect(try await iter.next() == nil)
        }

        @Test func sentenceAcrossTwoPagesWithHyphenation() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "First sentence. There is a particu-"),
                pdfPage(2, "larly comfortable hotel. Second page done."),
            ])

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "First sentence.")

            let second = try #require(try await iter.next() as? TextContentElement)
            #expect(second.text == "There is a particularly comfortable hotel.")
            try #require(second.segments.count == 2)
            #expect(second.segments[0].text == "There is a particu")
            #expect(second.segments[0].locator.text.highlight == "There is a particu-")
            #expect(second.segments[0].locator.locations.fragments == ["page=1"])
            #expect(second.segments[0].locator.text.after?.hasPrefix("larly comfortable hotel.") == true)
            #expect(second.segments[1].text == "larly comfortable hotel.")
            #expect(second.segments[1].attribute(.continued) == ContentContinuationJoiner.direct)
            #expect(second.segments[1].locator.locations.fragments == ["page=2"])
            #expect(second.segments[1].locator.text.highlight == "larly comfortable hotel.")
            #expect(second.locator.locations.fragments == ["page=1"])

            let third = try #require(try await iter.next() as? TextContentElement)
            #expect(third.text == "Second page done.")
            #expect(third.locator.locations.fragments == ["page=2"])

            #expect(try await iter.next() == nil)
        }

        @Test func spaceJoinedSentenceAcrossTwoPages() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "One starts here. The hungry cat sat on"),
                pdfPage(2, "the mat with style. Another sentence."),
            ])

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "One starts here.")

            let second = try #require(try await iter.next() as? TextContentElement)
            try #require(second.segments.count == 2)
            #expect(second.segments[0].text == "The hungry cat sat on")
            #expect(second.segments[1].text == " the mat with style.")
            #expect(second.segments[1].locator.text.highlight == "the mat with style.")
            #expect(second.segments[1].attribute(.continued) == ContentContinuationJoiner.space)

            let third = try #require(try await iter.next() as? TextContentElement)
            #expect(third.text == "Another sentence.")
        }

        @Test func abbreviationSeamNowMerges() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "A first sentence lives here. He greeted Mr."),
                pdfPage(2, "Smith warmly. Done."),
            ])

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "A first sentence lives here.")

            // "…said Mr." / "Smith came." used to be kept apart by the
            // terminal-punctuation fast path; the bridge test merges it.
            let second = try #require(try await iter.next() as? TextContentElement)
            #expect(second.text == "He greeted Mr. Smith warmly.")
            try #require(second.segments.count == 2)
            #expect(second.segments[0].locator.locations.fragments == ["page=1"])
            #expect(second.segments[1].locator.locations.fragments == ["page=2"])

            let third = try #require(try await iter.next() as? TextContentElement)
            #expect(third.text == "Done.")
        }

        @Test func uppercaseContinuationKeepsHyphenAndSpace() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "Starting out well. They visited Salt Lake-"),
                pdfPage(2, "City on their way westwards. Done."),
            ])

            _ = try await iter.next() // "Starting out well."
            let element = try #require(try await iter.next() as? TextContentElement)
            try #require(element.segments.count == 2)
            #expect(element.segments[0].text == "They visited Salt Lake-")
            #expect(element.segments[1].text == " City on their way westwards.")
            #expect(element.segments[1].attribute(.continued) == ContentContinuationJoiner.space)
        }

        @Test func threePageSentenceProducesOneElement() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "It begins. The story continues with something very"),
                pdfPage(2, "strange that keeps going on and on"),
                pdfPage(3, "until it finally ends here. Done."),
            ])

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "It begins.")

            let second = try #require(try await iter.next() as? TextContentElement)
            #expect(second.text == "The story continues with something very strange that keeps going on and on until it finally ends here.")
            try #require(second.segments.count == 3)
            #expect(second.segments.map(\.locator.locations.fragments) == [["page=1"], ["page=2"], ["page=3"]])

            let third = try #require(try await iter.next() as? TextContentElement)
            #expect(third.text == "Done.")

            #expect(try await iter.next() == nil)
        }

        @Test func paragraphGapNeverMerges() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "A paragraph without terminal punctuation\n\nAnother paragraph starts fresh"),
            ])

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "A paragraph without terminal punctuation")
            let second = try #require(try await iter.next() as? TextContentElement)
            #expect(second.text == "Another paragraph starts fresh")
            #expect(try await iter.next() == nil)
        }

        @Test func nonTextElementBreaksSeam() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "An unfinished sentence that keeps"),
                imageElement(),
                pdfPage(2, "going strong. Done."),
            ])

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "An unfinished sentence that keeps")
            #expect(try await iter.next() is ImageContentElement)
            let second = try #require(try await iter.next() as? TextContentElement)
            #expect(second.text == "going strong.")
            let third = try #require(try await iter.next() as? TextContentElement)
            #expect(third.text == "Done.")
        }

        @Test func pageNumberBecomesStandaloneArtifactElement() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "A full sentence.\n42"),
                pdfPage(2, "Second page done."),
            ])

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "A full sentence.")

            let artifact = try #require(try await iter.next() as? TextContentElement)
            #expect(artifact.text == "42")
            #expect(artifact.attribute(.pageArtifact) == PageArtifactKind.pageNumber)

            let second = try #require(try await iter.next() as? TextContentElement)
            #expect(second.text == "Second page done.")
        }

        @Test func runningFooterBecomesStandaloneArtifactElement() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "A full sentence here.\nMy Great Book"),
                pdfPage(2, "Second page text here.\nMy Great Book"),
            ])

            let elements = try await allForward(iter)
            let texts = elements.compactMap { ($0 as? TextContentElement)?.text }
            #expect(texts == [
                "A full sentence here.",
                "My Great Book",
                "Second page text here.",
                "My Great Book",
            ])
            let artifacts = elements.filter { $0.attribute(.pageArtifact) == PageArtifactKind.runningHeader }
            #expect(artifacts.count == 2)
        }

        @Test func lookaheadIsBounded() async throws {
            let (iter, mock) = makeIterator(
                (1 ... 20).map { pdfPage($0, "Page \($0) text ends here.") }
            )

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "Page 1 text ends here.")
            // Building the first window must not pull the whole publication.
            #expect(await mock.nextCallCount <= 6)
        }
    }

    struct HardBreaks {
        @Test func spacedCapsPageIsStandalone() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "Some intro sentence without end"),
                pdfPage(2, "P A R T O N E"),
                pdfPage(3, "The story begins here. More."),
            ])

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "Some intro sentence without end")

            let hardBreak = try #require(try await iter.next() as? TextContentElement)
            #expect(hardBreak.text == "P A R T O N E")
            #expect(hardBreak.attribute(.pageArtifact) == nil)
            #expect(hardBreak.locator.locations.fragments == ["page=2"])

            let second = try #require(try await iter.next() as? TextContentElement)
            #expect(second.text == "The story begins here.")
            let third = try #require(try await iter.next() as? TextContentElement)
            #expect(third.text == "More.")
        }

        @Test func spacedCapsPageIsStandaloneBackward() async throws {
            let elements = [
                pdfPage(1, "Some intro sentence without end"),
                pdfPage(2, "P A R T O N E"),
                pdfPage(3, "The story begins here. More."),
            ]
            let (forward, _) = makeIterator(elements)
            let forwardElements = try await allForward(forward)

            let (backward, _) = makeIterator(elements, startingAtEnd: true)
            let backwardElements = try await allBackward(backward)

            #expect(backwardElements.map { $0.equatable() } == forwardElements.reversed().map { $0.equatable() })
        }

        @Test func chapterLineIsStandalone() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "Chapter 1\nIt was a dark night. More text."),
            ])

            let hardBreak = try #require(try await iter.next() as? TextContentElement)
            #expect(hardBreak.text == "Chapter 1")
            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "It was a dark night.")
        }

        @Test func headingRoleElementIsStandalone() async throws {
            let (iter, _) = makeIterator([
                fxlElement("p1.xhtml", "A Very Nice Story", role: .heading(level: 1)),
                fxlElement("p1.xhtml", "It was a dark night. The end."),
            ])

            let heading = try #require(try await iter.next() as? TextContentElement)
            #expect(heading.text == "A Very Nice Story")
            #expect(heading.role == .heading(level: 1))

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "It was a dark night.")
        }
    }

    struct FixedLayoutElements {
        @Test func samePageBlockElementsMergeIntoOneSentence() async throws {
            let (iter, _) = makeIterator([
                fxlElement("bella.xhtml", "There lived a beautiful", cssSelector: "#div1"),
                fxlElement("bella.xhtml", "kind, friendly dragon,", cssSelector: "#div2"),
                fxlElement("bella.xhtml", "named Bella.", cssSelector: "#div3"),
            ])

            let element = try #require(try await iter.next() as? TextContentElement)
            #expect(element.text == "There lived a beautiful kind, friendly dragon, named Bella.")
            try #require(element.segments.count == 3)
            #expect(element.segments[0].text == "There lived a beautiful")
            #expect(element.segments[1].text == " kind, friendly dragon,")
            #expect(element.segments[1].attribute(.continued) == ContentContinuationJoiner.space)
            #expect(element.segments[2].text == " named Bella.")
            #expect(element.segments[2].attribute(.continued) == ContentContinuationJoiner.space)

            // Each part keeps its own block element locator.
            #expect(element.segments.map(\.locator.locations.cssSelector) == ["#div1", "#div2", "#div3"])

            #expect(try await iter.next() == nil)
        }

        @Test func ellipsisMergesLowercaseAndSplitsUppercase() async throws {
            let (iter, _) = makeIterator([
                fxlElement("p1.xhtml", "Far, far away ..."),
                fxlElement("p1.xhtml", "and beyond the sea."),
                fxlElement("p1.xhtml", "There it was."),
            ])

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "Far, far away ... and beyond the sea.")
            #expect(first.segments.count == 2)

            let second = try #require(try await iter.next() as? TextContentElement)
            #expect(second.text == "There it was.")
        }

        @Test func sentenceAcrossResourcesLandsInLeftResource() async throws {
            let (iter, _) = makeIterator([
                fxlElement("p1.xhtml", "Intro sentence one. The hungry cat sat on"),
                fxlElement("p2.xhtml", "the mat with style. Another sentence here."),
            ])

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "Intro sentence one.")

            let second = try #require(try await iter.next() as? TextContentElement)
            #expect(second.text == "The hungry cat sat on the mat with style.")
            try #require(second.segments.count == 2)
            #expect(second.segments[0].locator.href.string == "p1.xhtml")
            #expect(second.segments[1].locator.href.string == "p2.xhtml")
            #expect(second.locator.href.string == "p1.xhtml")

            let third = try #require(try await iter.next() as? TextContentElement)
            #expect(third.text == "Another sentence here.")
            #expect(third.locator.href.string == "p2.xhtml")
        }

        @Test func artifactSegmentWithinAnElementDoesNotGlueWords() async throws {
            // The page number is the first *segment* of the next page's
            // element: the body segment after it must not be joined directly
            // to the previous page as if it were contiguous with the number.
            let (iter, _) = makeIterator([
                fxlElement("p1.xhtml", "Intro sentence one. The hungry cat sat on"),
                fxlElement("p2.xhtml", segments: ["42", "the mat with style. Done here."]),
            ])

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "Intro sentence one.")

            let second = try #require(try await iter.next() as? TextContentElement)
            #expect(second.text == "The hungry cat sat on the mat with style.")
            #expect(second.segments.last?.attribute(.continued) == ContentContinuationJoiner.space)

            let artifact = try #require(try await iter.next() as? TextContentElement)
            #expect(artifact.text == "42")
            #expect(artifact.attribute(.pageArtifact) == PageArtifactKind.pageNumber)

            let third = try #require(try await iter.next() as? TextContentElement)
            #expect(third.text == "Done here.")
        }

        @Test func pageNumberElementBetweenSentenceParts() async throws {
            let (iter, _) = makeIterator([
                fxlElement("p1.xhtml", "Intro sentence one. The hungry cat sat on"),
                fxlElement("p2.xhtml", "42"),
                fxlElement("p2.xhtml", "the mat with style. Another sentence here."),
            ])

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "Intro sentence one.")

            // The sentence merges past the standalone page number element,
            // which is emitted right after it.
            let second = try #require(try await iter.next() as? TextContentElement)
            #expect(second.text == "The hungry cat sat on the mat with style.")

            let artifact = try #require(try await iter.next() as? TextContentElement)
            #expect(artifact.text == "42")
            #expect(artifact.attribute(.pageArtifact) == PageArtifactKind.pageNumber)

            let third = try #require(try await iter.next() as? TextContentElement)
            #expect(third.text == "Another sentence here.")
        }
    }

    struct MidStart {
        @Test func startsWithTheFullStraddlingSentence() async throws {
            let elements = [
                pdfPage(1, "First one. The hungry cat sat on"),
                pdfPage(2, "the mat with style. Another one here."),
            ]

            // Start on the second page, as `PublicationContentIterator` does
            // when given a mid-publication locator.
            let (iter, _) = makeIterator(elements, startIndex: 1)

            // The first returned element is the full sentence containing the
            // start position, even though it began on the previous page.
            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "The hungry cat sat on the mat with style.")

            // Going backward returns the element before it.
            let previous = try #require(try await iter.previous() as? TextContentElement)
            #expect(previous.text == "First one.")
        }
    }

    struct BackwardIteration {
        @Test func backwardFromEndEqualsReversedForward() async throws {
            // Running footers force neighbor-dependent classification, and
            // 12 single-sentence pages produce more windows than the window
            // cache holds, exercising re-derivation after eviction.
            let elements = (1 ... 12).map {
                pdfPage($0, "Sentence number \($0) lives right here.\nMy Great Book")
            }

            let (forward, _) = makeIterator(elements)
            let forwardElements = try await allForward(forward)

            let (backward, _) = makeIterator(elements, startingAtEnd: true)
            let backwardElements = try await allBackward(backward)

            #expect(backwardElements.map { $0.equatable() } == forwardElements.reversed().map { $0.equatable() })
        }

        @Test func alternatingDirectionsIsConsistent() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "First sentence. There is a particu-"),
                pdfPage(2, "larly comfortable hotel. Second page done."),
            ])

            let first = try #require(try await iter.next()).equatable()
            let second = try #require(try await iter.next()).equatable()
            let backToFirst = try #require(try await iter.previous()).equatable()
            let secondAgain = try #require(try await iter.next()).equatable()

            #expect(backToFirst == first)
            #expect(secondAgain == second)
        }
    }

    struct Caps {
        @Test func punctuationlessPagesStayBounded() async throws {
            let elements = (1 ... 6).map {
                pdfPage($0, "alpha bravo charlie delta page \($0)")
            }

            let (forward, _) = makeIterator(elements)
            let forwardElements = try await allForward(forward)

            // Every element spans at most 4 pages.
            for element in forwardElements {
                let text = try #require(element as? TextContentElement)
                let pages = Set(text.segments.flatMap(\.locator.locations.fragments))
                #expect(pages.count <= 4)
            }
            // All 6 pages are covered.
            let allPages = Set(
                forwardElements
                    .compactMap { $0 as? TextContentElement }
                    .flatMap { $0.segments.flatMap(\.locator.locations.fragments) }
            )
            #expect(allPages.count == 6)

            let (backward, _) = makeIterator(elements, startingAtEnd: true)
            let backwardElements = try await allBackward(backward)
            #expect(backwardElements.map { $0.equatable() } == forwardElements.reversed().map { $0.equatable() })
        }

        @Test func fragmentCapBoundsPunctuationlessFXLPages() async throws {
            let elements = (1 ... 250).map { i in
                fxlElement("page.xhtml", "word\(i)")
            }

            let (iter, _) = makeIterator(elements)
            let results = try await allForward(iter)
                .compactMap { $0 as? TextContentElement }

            // The region is split at the fragment cap instead of growing
            // without bound.
            #expect(results.count >= 2)
            for element in results {
                #expect(element.segments.count <= 200)
            }
            let totalSegments = results.map(\.segments.count).reduce(0, +)
            #expect(totalSegments == 250)
        }
    }

    struct SearchInvariant {
        @Test func segmentTextsJoinToTheLogicalSentence() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "First sentence. There is a particu-\nlarly comfortable hotel in"),
                pdfPage(2, "this town. Second page done."),
            ])

            // Expected logical sentences, computed independently of the
            // iterator's own text assembly.
            let expected = [
                "First sentence.",
                "There is a particularly comfortable hotel in this town.",
                "Second page done.",
            ]

            let elements = try await allForward(iter).compactMap { $0 as? TextContentElement }
            #expect(elements.map { $0.segments.map(\.text).joined() } == expected)
        }

        @Test func searchWindowReconstructionSkipsPageArtifacts() async throws {
            let (iter, _) = makeIterator([
                pdfPage(1, "The cat sat on the mat.\n7"),
                pdfPage(2, "A dog barked loudly. End."),
            ])

            let elements = try await allForward(iter).compactMap { $0 as? TextContentElement }

            // Reconstruct the text the search service's sliding window sees:
            // element texts joined by single spaces, page artifacts skipped.
            let searched = elements
                .filter { $0.attribute(.pageArtifact) == nil }
                .map { $0.segments.map(\.text).joined() }
                .joined(separator: " ")
            #expect(searched == "The cat sat on the mat. A dog barked loudly. End.")

            // A query spanning the two sentences around the seam matches,
            // despite the page number sitting between them on the page.
            #expect(searched.contains("mat. A dog"))
        }
    }

    struct Progressions {
        @Test func pdfProgressionsAreMonotonicAndWithinPageBrackets() async throws {
            let pageCount = 4
            let (iter, _) = makeIterator([
                pdfPage(1, "One one one. Two two two.", pageCount: pageCount),
                pdfPage(2, "Three three. Four four four.", pageCount: pageCount),
                pdfPage(3, "Five five five. Six six six.", pageCount: pageCount),
            ])

            let elements = try await allForward(iter).compactMap { $0 as? TextContentElement }
            try #require(elements.count == 6)

            var lastProgression = 0.0
            for element in elements {
                let progression = try #require(element.locator.locations.progression)
                #expect(progression >= lastProgression)
                lastProgression = progression

                // In-bracket: restarting from this locator must land on the
                // element's own page.
                let page = try #require(element.locator.locations.fragments.first
                    .flatMap { Int($0.dropFirst("page=".count)) })
                let bracket = Double(page - 1) / Double(pageCount) ..< Double(page) / Double(pageCount)
                #expect(bracket.contains(progression) || progression == bracket.lowerBound)
            }
        }
    }

    struct CJK {
        @Test func spacelessScriptJoinsDirectly() async throws {
            let (iter, _) = makeIterator(
                [
                    pdfPage(1, "これは長い文章で"),
                    pdfPage(2, "続きです。次の文です。"),
                ],
                language: Language(code: .bcp47("ja"))
            )

            let first = try #require(try await iter.next() as? TextContentElement)
            #expect(first.text == "これは長い文章で続きです。")
            try #require(first.segments.count == 2)
            #expect(first.segments[1].text == "続きです。")
            #expect(first.segments[1].attribute(.continued) == ContentContinuationJoiner.direct)

            let second = try #require(try await iter.next() as? TextContentElement)
            #expect(second.text == "次の文です。")
        }
    }
}

// MARK: - Helpers

private func allForward(_ iterator: SentenceContentIterator) async throws -> [ContentElement] {
    var elements: [ContentElement] = []
    while let element = try await iterator.next() {
        elements.append(element)
    }
    return elements
}

private func allBackward(_ iterator: SentenceContentIterator) async throws -> [ContentElement] {
    var elements: [ContentElement] = []
    while let element = try await iterator.previous() {
        elements.append(element)
    }
    return elements
}

private func pdfPage(_ number: Int, _ text: String, pageCount: Int? = nil) -> TextContentElement {
    let locator = Locator(href: "book.pdf", mediaType: .pdf).copy(
        locations: {
            $0.fragments = ["page=\(number)"]
            $0.position = number
            if let pageCount {
                $0.progression = Double(number - 1) / Double(pageCount)
            }
        },
        text: {
            $0 = Locator.Text(highlight: text)
        }
    )
    return TextContentElement(
        locator: locator,
        role: .body,
        segments: [TextContentElement.Segment(locator: locator, text: text)]
    )
}

private func fxlElement(
    _ href: String,
    _ text: String,
    role: TextContentElement.Role = .body,
    cssSelector: String? = nil
) -> TextContentElement {
    let locator = Locator(href: href, mediaType: .xhtml).copy(
        locations: {
            $0.cssSelector = cssSelector
        },
        text: {
            $0 = Locator.Text(highlight: text)
        }
    )
    return TextContentElement(
        locator: locator,
        role: role,
        segments: [TextContentElement.Segment(locator: locator, text: text)]
    )
}

private func fxlElement(_ href: String, segments: [String]) -> TextContentElement {
    let locator = Locator(href: href, mediaType: .xhtml).copy(
        text: {
            $0 = Locator.Text(highlight: segments.joined())
        }
    )
    return TextContentElement(
        locator: locator,
        role: .body,
        segments: segments.map { TextContentElement.Segment(locator: locator, text: $0) }
    )
}

private func imageElement() -> ImageContentElement {
    ImageContentElement(
        locator: Locator(href: "img.png", mediaType: .png),
        embeddedLink: Link(href: "img.png")
    )
}

private func makeIterator(
    _ elements: [ContentElement],
    startIndex: Int? = nil,
    startingAtEnd: Bool = false,
    language: Language? = Language(code: .bcp47("en"))
) -> (SentenceContentIterator, MockContentIterator) {
    let mock = MockContentIterator(elements, startIndex: startIndex, startingAtEnd: startingAtEnd)
    let iterator = SentenceContentIterator(iterator: mock, language: language)
    return (iterator, mock)
}

/// A `ContentIterator` over a fixed list of elements, with the same cursor
/// semantics as `PDFResourceContentIterator`, counting the calls it receives.
actor MockContentIterator: ContentIterator {
    private let elements: [ContentElement]

    /// Index of the last returned element.
    private var index: Int?

    private(set) var nextCallCount = 0
    private(set) var previousCallCount = 0

    init(_ elements: [ContentElement], startIndex: Int? = nil, startingAtEnd: Bool = false) {
        self.elements = elements
        if let startIndex {
            index = startIndex - 1
        } else {
            index = startingAtEnd ? elements.count : nil
        }
    }

    func next() async throws -> ContentElement? {
        nextCallCount += 1
        let target = (index ?? -1) + 1
        guard elements.indices.contains(target) else {
            return nil
        }
        index = target
        return elements[target]
    }

    func previous() async throws -> ContentElement? {
        previousCallCount += 1
        let target = (index ?? 0) - 1
        guard elements.indices.contains(target) else {
            return nil
        }
        index = target
        return elements[target]
    }
}
