//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

enum PDFResourceContentIteratorTests {
    struct Navigation {
        @Test func iterateFromStartToFinish() async throws {
            let iter = makeIterator()
            for expected in sampleElements {
                let result = try await iter.next()
                #expect(result?.equatable() == expected)
            }
            let result = try await iter.next()
            #expect(result == nil)
        }

        @Test func previousIsNullFromTheBeginning() async throws {
            let result = try await makeIterator().previous()
            #expect(result == nil)
        }

        @Test func nextReturnsTheFirstElementFromTheBeginning() async throws {
            let result = try await makeIterator().next()
            #expect(result?.equatable() == sampleElements[0])
        }

        @Test func nextThenPreviousReturnsNull() async throws {
            let iter = makeIterator()
            let first = try await iter.next()
            #expect(first?.equatable() == sampleElements[0])
            let back = try await iter.previous()
            #expect(back == nil)
        }

        @Test func nextTwiceThenPreviousReturnsTheFirstElement() async throws {
            let iter = makeIterator()
            let first = try await iter.next()
            #expect(first?.equatable() == sampleElements[0])
            let second = try await iter.next()
            #expect(second?.equatable() == sampleElements[1])
            let back = try await iter.previous()
            #expect(back?.equatable() == sampleElements[0])
        }

        @Test func iterateBackwardFromEnd() async throws {
            // Starting at end: startIndex = count - 1 = 7
            let iter = makeIterator(start: makeLocator(progression: 1.0))
            let last = try await iter.next()
            #expect(last?.equatable() == sampleElements[7])
            let secondToLast = try await iter.previous()
            #expect(secondToLast?.equatable() == sampleElements[6])
        }
    }

    struct StartingPosition {
        @Test func startingFromPosition() async throws {
            // Position 5 = page 5 = element at index 3 in the non-empty array
            let result = try await makeIterator(start: makeLocator(position: 5)).next()
            #expect(result?.equatable() == sampleElements[3])
        }

        @Test func startingFromProgression() async throws {
            // Pre-adjustment progressions: [1/9, 2/9, 3/9, ...]; 0.4 > 3/9≈0.333, so
            // lastIndex where progression ≤ 0.4 is index 2 (3/9). First next() → element 2 (page 4).
            let result = try await makeIterator(start: makeLocator(progression: 0.4)).next()
            #expect(result?.equatable() == sampleElements[2])
        }

        @Test func startingFromEndProgression() async throws {
            let iter = makeIterator(start: makeLocator(progression: 1.0))
            let first = try await iter.next()
            #expect(first?.equatable() == sampleElements[7])
            let second = try await iter.next()
            #expect(second == nil)
        }
    }

    struct ContentCorrectness {
        @Test func emptyPagesAreSkipped() async throws {
            let iter = makeIterator()
            var count = 0
            while let _ = try await iter.next() {
                count += 1
            }
            #expect(count == 8)
        }

        @Test func elementLocatorHasCorrectPagePosition() async throws {
            let iter = makeIterator()
            let expectedPageNumbers = [2, 3, 4, 5, 6, 7, 8, 9]
            for expected in expectedPageNumbers {
                let element = try await iter.next()
                #expect(element?.locator.locations.position == expected)
            }
        }

        @Test func elementLocatorHasProgression() async throws {
            let iter = makeIterator()
            for i in 0 ..< 8 {
                let element = try await iter.next()
                #expect(element?.locator.locations.progression == Double(i) / 8.0)
            }
        }

        @Test func beforeSnippetIsPopulatedAfterFirstPage() async throws {
            let iter = makeIterator()
            let first = try await iter.next()
            #expect(first?.locator.text.before == nil)
            let second = try await iter.next()
            #expect(second?.locator.text.before == p3Before)
        }

        @Test func highlightSnippetIsPrefix() async throws {
            let iter = makeIterator()
            // Verify a long page: page 7 (index 5), whose text exceeds 280 chars
            for _ in 0 ..< 5 {
                _ = try await iter.next()
            }
            let element = try await iter.next()
            #expect(element?.locator.text.highlight == String(p7Text.prefix(280)))
        }

        @Test func segmentTextMatchesFullPageText() async throws {
            let iter = makeIterator()
            let pageFull = [p2Text, p3Text, p4Text, p5Text, p6Text, p7Text, p8Text, p9Text]
            for expected in pageFull {
                let element = try await iter.next() as? TextContentElement
                #expect(element?.segments.first?.text == expected)
            }
        }
    }

    struct TotalProgression {
        @Test func totalProgressionIsAdjustedWithRange() async throws {
            let range: ClosedRange<Double> = 0.25 ... 0.75
            let iter = makeIterator(totalProgressionRange: range)
            for i in 0 ..< 8 {
                let element = try await iter.next()
                let expected = range.lowerBound + Double(i) / 8.0 * (range.upperBound - range.lowerBound)
                #expect(element?.locator.locations.totalProgression == expected)
            }
        }

        @Test func totalProgressionIsNullWithoutRange() async throws {
            let iter = makeIterator()
            for _ in 0 ..< 8 {
                let element = try await iter.next()
                #expect(element?.locator.locations.totalProgression == nil)
            }
        }
    }
}

// MARK: - Helpers

private let baseLocator = Locator(href: "daisy-truncated.pdf", mediaType: .pdf)

// Page texts extracted via PDFKit from daisy-truncated.pdf
private let p2Text = "D A I S Y M I L L E R"
private let p3Text = "DAISY MILLER\nBy Henry James"
private let p4Text = "Daisy Miller"
private let p5Text = "C O N T E N T S\nPA R T O N E\n1\nPA R T T W O\n1 7\nPA R T T H R E E\n3 6\nPA R T F O U R\n5 4"
private let p6Text = "P A R T O N E"
// swiftlint:disable line_length
private let p7Text = "At the little town of Vevey, in Switzerland, there is a particu-\nlarly comfortable hotel. There are, indeed, many hotels, for the\nentertainment of tourists is the business of the place, which, as\nmany travelers will remember, is seated upon the edge of a\nremarkably blue lake\u{2014}a lake that it behooves every tourist to\nvisit. The shore of the lake presents an unbroken array of estab-\nlishments of this order, of every category, from the \"grand hotel\u{201D}\nof the newest fashion, with a chalk-white front, a hundred bal-\nconies, and a dozen flags flying from its roof, to the little Swiss\npension of an elder day, with its name inscribed in German-look-\ning lettering upon a pink or yellow wall and an awkward sum-\nmerhouse in the angle of the garden. One of the hotels at Vevey,\nhowever, is famous, even classical, being distinguished from\nmany of its upstart neighbors by an air both of luxury and of\nmaturity. In this region, in the month of June, American travel-\ners are extremely numerous; it may be said, indeed, that Vevey\nassumes at this period some of the characteristics of an American\nwatering place. There are sights and sounds which evoke a\nvision, an echo, of Newport and Saratoga. There is a flitting\nhither and thither of \u{201C}stylish\u{201D} young girls, a rustling of muslin\nflounces, a rattle of dance music in the morning hours, a sound\nof high-pitched voices at all times. You receive an impression of\nthese things at the excellent inn of the \u{201C}Trois Couronnes\u{201D} and are\ntransported in fancy to the Ocean House or to Congress Hall.\nBut at the \u{201C}Trois Couronnes,\u{201D} it must be added, there are other\nfeatures that are much at variance with these suggestions: neat\nGerman waiters, who look like secretaries of legation; Russian\n2"
private let p8Text = "princesses sitting in the garden; little Polish boys walking about\nheld by the hand, with their governors; a view of the sunny crest\nof the Dent du Midi and the picturesque towers of the Castle of\nChillon.\nI hardly know whether it was the analogies or the differences\nthat were uppermost in the mind of a young American, who,\ntwo or three years ago, sat in the garden of the \u{201C}Trois\nCouronnes,\u{201D} looking about him, rather idly, at some of the\ngraceful objects I have mentioned. It was a beautiful summer\nmorning, and in whatever fashion the young American looked at\nthings, they must have seemed to him charming. He had come\nfrom Geneva the day before by the little steamer, to see his aunt,\nwho was staying at the hotel\u{2014}Geneva having been for a long\ntime his place of residence. But his aunt had a headache\u{2014}his\naunt had almost always a headache\u{2014}and now she was shut up in\nher room, smelling camphor, so that he was at liberty to wander\nabout. He was some seven-and-twenty years of age; when his\nfriends spoke of him, they usually said that he was at Geneva\n\u{201C}studying.\u{201D}When his enemies spoke of him, they said\u{2014}but, after\nall, he had no enemies; he was an extremely amiable fellow, and\nuniversally liked.What I should say is, simply, that when certain\npersons spoke of him they affirmed that the reason of his spend-\ning so much time at Geneva was that he was extremely devoted\nto a lady who lived there\u{2014}a foreign lady\u{2014}a person older than\nhimself. Very few Americans\u{2014}indeed, I think none\u{2014}had ever\nseen this lady, about whom there were some singular stories. But\nWinterbourne had an old attachment for the little metropolis of\nCalvinism; he had been put to school there as a boy, and he had\nafterward gone to college there\u{2014}circumstances which had led\nto his forming a great many youthful friendships. Many of these\nhe had kept, and they were a source of great satisfaction to him.\nAfter knocking at his aunt\u{2019}s door and learning that she was\nD A I S Y M I L L E R\n3"
// swiftlint:enable line_length
private let p9Text = "Nevertheless, he went back to live at Geneva, whence there\ncontinue to come the most contradictory accounts of his\nmotives of sojourn: a report that he is \u{201C}studying\u{201D} hard—an inti-\nmation that he is much interested in a very clever foreign lady.\nThe End\nD A I S Y M I L L E R\n75"

// `before` snippets: suffix(50) of text accumulated before each page.
private let p3Before = "D A I S Y M I L L E R\n\n"
private let p4Before = "A I S Y M I L L E R\n\nDAISY MILLER\nBy Henry James\n\n"
private let p5Before = "L E R\n\nDAISY MILLER\nBy Henry James\n\nDaisy Miller\n\n"
private let p6Before = " W O\n1 7\nPA R T T H R E E\n3 6\nPA R T F O U R\n5 4\n\n"
private let p7Before = " T H R E E\n3 6\nPA R T F O U R\n5 4\n\nP A R T O N E\n\n"
private let p8Before = "who look like secretaries of legation; Russian\n2\n\n"
private let p9Before = "nd learning that she was\nD A I S Y M I L L E R\n3\n\n"

private func makeElement(
    pageNumber: Int,
    progressionIndex: Int,
    text: String,
    before: String? = nil
) -> AnyEquatableContentElement {
    let progression = Double(progressionIndex) / 8.0
    let loc = makeLocator(
        position: pageNumber,
        progression: progression,
        before: before,
        highlight: String(text.prefix(280))
    )
    return TextContentElement(
        locator: loc,
        role: .body,
        segments: [TextContentElement.Segment(locator: loc, text: text)]
    ).equatable()
}

private let sampleElements: [AnyEquatableContentElement] = [
    makeElement(pageNumber: 2, progressionIndex: 0, text: p2Text),
    makeElement(pageNumber: 3, progressionIndex: 1, text: p3Text, before: p3Before),
    makeElement(pageNumber: 4, progressionIndex: 2, text: p4Text, before: p4Before),
    makeElement(pageNumber: 5, progressionIndex: 3, text: p5Text, before: p5Before),
    makeElement(pageNumber: 6, progressionIndex: 4, text: p6Text, before: p6Before),
    makeElement(pageNumber: 7, progressionIndex: 5, text: p7Text, before: p7Before),
    makeElement(pageNumber: 8, progressionIndex: 6, text: p8Text, before: p8Before),
    makeElement(pageNumber: 9, progressionIndex: 7, text: p9Text, before: p9Before),
]

private func makeLocator(
    position: Int? = nil,
    progression: Double? = nil,
    before: String? = nil,
    highlight: String? = nil
) -> Locator {
    baseLocator.copy(
        locations: {
            $0.position = position
            $0.progression = progression
        },
        text: {
            $0.before = before
            $0.highlight = highlight
        }
    )
}

private func makeIterator(
    start startLocator: Locator? = nil,
    totalProgressionRange: ClosedRange<Double>? = nil
) -> PDFResourceContentIterator {
    let data = Fixtures(path: "Publication/Services").data(at: "daisy-truncated.pdf")
    return PDFResourceContentIterator(
        resource: DataResource(data: data),
        totalProgressionRange: { totalProgressionRange },
        locator: startLocator ?? baseLocator
    )
}
