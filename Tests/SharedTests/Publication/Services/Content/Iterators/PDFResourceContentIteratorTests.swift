//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing
import UIKit

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

        @Test func iterateFullyBackwardFromEnd() async throws {
            let iter = makeIterator(start: makeLocator(progression: 1.0))
            _ = try await iter.next() // Position at last element

            var backwardElements: [AnyEquatableContentElement] = []
            while let element = try await iter.previous() {
                backwardElements.append(element.equatable())
            }

            #expect(backwardElements == sampleElements.dropLast().reversed())
        }
    }

    struct StartingPosition {
        @Test func startingFromPosition() async throws {
            let result = try await makeIterator(start: makeLocator(position: 5)).next()
            #expect(result?.equatable() == makeElement(pageNumber: 5, text: p5Text))
        }

        @Test func startingFromPageFragment() async throws {
            // page=5 fragment should land on the same element as position 5.
            let result = try await makeIterator(start: makeLocator(pageFragment: 5)).next()
            #expect(result?.equatable() == makeElement(pageNumber: 5, text: p5Text))
        }

        @Test func startingFromProgression() async throws {
            // progression=0.4, pageCount=9 → startPage = min(Int(0.4*9),8) = 3 (page 4).
            let result = try await makeIterator(start: makeLocator(progression: 0.4)).next()
            #expect(result?.equatable() == makeElement(pageNumber: 4, text: p4Text))
        }

        @Test func startingFromEndProgression() async throws {
            let iter = makeIterator(start: makeLocator(progression: 1.0))
            let first = try await iter.next()
            #expect(first?.equatable() == makeElement(pageNumber: 9, text: p9Text))
            let second = try await iter.next()
            #expect(second == nil)
        }
    }

    struct ContentCorrectness {
        @Test func zeroPagesReturnsNil() async throws {
            let mock = MockPDFDocument(texts: [])
            let iter = makeIteratorFromMock(mock)

            #expect(try await iter.next() == nil)
            #expect(try await iter.previous() == nil)
        }

        @Test func emptyPagesAreSkipped() async throws {
            let iter = makeIterator()
            var pageNumbers: [Int] = []
            while let element = try await iter.next() {
                pageNumbers.append(element.locator.locations.page ?? 0)
            }
            #expect(pageNumbers == [2, 3, 4, 5, 6, 7, 8, 9])
        }

        @Test func allEmptyPagesReturnsNil() async throws {
            let mock = MockPDFDocument(texts: [nil, "", "   ", "\n\t"])
            let iter = makeIteratorFromMock(mock)
            #expect(try await iter.next() == nil)
        }

        @Test func elementLocatorHasCorrectPagePosition() async throws {
            let iter = makeIterator()
            let expectedPageNumbers = [2, 3, 4, 5, 6, 7, 8, 9]
            for expected in expectedPageNumbers {
                let element = try await iter.next()
                #expect(element?.locator.locations.position == expected)
            }
        }

        @Test func elementLocatorHasPageFragment() async throws {
            let iter = makeIterator()
            let expectedPageNumbers = [2, 3, 4, 5, 6, 7, 8, 9]
            for expected in expectedPageNumbers {
                let element = try await iter.next()
                #expect(element?.locator.locations.fragments == ["page=\(expected)"])
            }
        }

        @Test func elementLocatorHasProgression() async throws {
            let iter = makeIterator()
            for i in 0 ..< 8 {
                let element = try await iter.next()
                #expect(element?.locator.locations.progression == Double(i + 1) / 9.0)
            }
        }

        @Test func highlightIsFullPageText() async throws {
            let iter = makeIterator()
            let pageFull = [p2Text, p3Text, p4Text, p5Text, p6Text, p7Text, p8Text, p9Text]
            for expected in pageFull {
                let element = try await iter.next()
                #expect(element?.locator.text.highlight == expected)
            }
        }

        @Test func segmentTextMatchesFullPageText() async throws {
            let iter = makeIterator()
            let pageFull = [p2Text, p3Text, p4Text, p5Text, p6Text, p7Text, p8Text, p9Text]
            for expected in pageFull {
                let element = try await iter.next() as? TextContentElement
                #expect(element?.text == expected)
            }
        }
    }

    struct TotalProgression {
        @Test func totalProgressionIsAdjustedWithRange() async throws {
            let range: ClosedRange<Double> = 0.25 ... 0.75
            let iter = makeIterator(totalProgressionRange: range)
            for i in 0 ..< 8 {
                let element = try await iter.next()
                let expected = range.lowerBound + Double(i + 1) / 9.0 * (range.upperBound - range.lowerBound)
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

    struct PositionOffset {
        @Test func positionsAreOffsetByPositionOffset() async throws {
            // offset 10: pages 1–9 of the PDF map to global positions 11–19
            let iter = makeIterator(positionOffset: 10)
            let expectedPositions = [12, 13, 14, 15, 16, 17, 18, 19]
            for expected in expectedPositions {
                let element = try await iter.next()
                #expect(element?.locator.locations.position == expected)
            }
        }

        @Test func startingFromGlobalPositionWithOffset() async throws {
            // position 12 with offset 10 = page 2 of the PDF = sampleElements[0] (first non-empty page)
            let iter = makeIterator(
                start: makeLocator(position: 12),
                positionOffset: 10
            )
            let first = try await iter.next()
            // position 12 maps to the element with position 12 (pageNumber=2, offset=10 → 12)
            #expect(first?.locator.locations.position == 12)
        }

        @Test func pageFragmentStartStillWorksWithOffset() async throws {
            // page=5 fragment should still land on the element for page 5, regardless of offset
            let iter = makeIterator(
                start: makeLocator(pageFragment: 5),
                positionOffset: 10
            )
            let first = try await iter.next()
            #expect(first?.locator.locations.fragments == ["page=5"])
        }
    }

    struct ErrorHandling {
        @Test func openDocumentErrorPropagates() async throws {
            struct TestError: Error {}
            let iter = PDFResourceContentIterator(
                openDocument: { throw TestError() },
                resourceInfo: { PDFResourceContentIterator.ResourceInfo(positionOffset: 0, totalProgressionRange: nil) },
                locator: Locator(href: "mock.pdf", mediaType: .pdf)
            )
            await #expect(throws: TestError.self) {
                _ = try await iter.next()
            }
        }

        @Test func documentWithoutTextSupportProducesNoElements() async throws {
            let iter = PDFResourceContentIterator(
                openDocument: { MockNonTextPDFDocument() },
                resourceInfo: { PDFResourceContentIterator.ResourceInfo(positionOffset: 0, totalProgressionRange: nil) },
                locator: Locator(href: "mock.pdf", mediaType: .pdf)
            )
            let result = try await iter.next()
            #expect(result == nil)
        }
    }
}

// MARK: - Helpers

private let baseLocator = Locator(href: "daisy-truncated.pdf", mediaType: .pdf)

private let p2Text = "D A I S Y M I L L E R"
private let p3Text = "DAISY MILLER\nBy Henry James"
private let p4Text = "Daisy Miller"
private let p5Text = "C O N T E N T S\nPA R T O N E\n1\nPA R T T W O\n1 7\nPA R T T H R E E\n3 6\nPA R T F O U R\n5 4"
private let p6Text = "P A R T O N E"
private let p7Text = "At the little town of Vevey, in Switzerland, there is a particu-\nlarly comfortable hotel. There are, indeed, many hotels, for the\nentertainment of tourists is the business of the place, which, as\nmany travelers will remember, is seated upon the edge of a\nremarkably blue lake\u{2014}a lake that it behooves every tourist to\nvisit. The shore of the lake presents an unbroken array of estab-\nlishments of this order, of every category, from the \"grand hotel\u{201D}\nof the newest fashion, with a chalk-white front, a hundred bal-\nconies, and a dozen flags flying from its roof, to the little Swiss\npension of an elder day, with its name inscribed in German-look-\ning lettering upon a pink or yellow wall and an awkward sum-\nmerhouse in the angle of the garden. One of the hotels at Vevey,\nhowever, is famous, even classical, being distinguished from\nmany of its upstart neighbors by an air both of luxury and of\nmaturity. In this region, in the month of June, American travel-\ners are extremely numerous; it may be said, indeed, that Vevey\nassumes at this period some of the characteristics of an American\nwatering place. There are sights and sounds which evoke a\nvision, an echo, of Newport and Saratoga. There is a flitting\nhither and thither of \u{201C}stylish\u{201D} young girls, a rustling of muslin\nflounces, a rattle of dance music in the morning hours, a sound\nof high-pitched voices at all times. You receive an impression of\nthese things at the excellent inn of the \u{201C}Trois Couronnes\u{201D} and are\ntransported in fancy to the Ocean House or to Congress Hall.\nBut at the \u{201C}Trois Couronnes,\u{201D} it must be added, there are other\nfeatures that are much at variance with these suggestions: neat\nGerman waiters, who look like secretaries of legation; Russian\n2"
private let p8Text = "princesses sitting in the garden; little Polish boys walking about\nheld by the hand, with their governors; a view of the sunny crest\nof the Dent du Midi and the picturesque towers of the Castle of\nChillon.\nI hardly know whether it was the analogies or the differences\nthat were uppermost in the mind of a young American, who,\ntwo or three years ago, sat in the garden of the \u{201C}Trois\nCouronnes,\u{201D} looking about him, rather idly, at some of the\ngraceful objects I have mentioned. It was a beautiful summer\nmorning, and in whatever fashion the young American looked at\nthings, they must have seemed to him charming. He had come\nfrom Geneva the day before by the little steamer, to see his aunt,\nwho was staying at the hotel\u{2014}Geneva having been for a long\ntime his place of residence. But his aunt had a headache\u{2014}his\naunt had almost always a headache\u{2014}and now she was shut up in\nher room, smelling camphor, so that he was at liberty to wander\nabout. He was some seven-and-twenty years of age; when his\nfriends spoke of him, they usually said that he was at Geneva\n\u{201C}studying.\u{201D}When his enemies spoke of him, they said\u{2014}but, after\nall, he had no enemies; he was an extremely amiable fellow, and\nuniversally liked.What I should say is, simply, that when certain\npersons spoke of him they affirmed that the reason of his spend-\ning so much time at Geneva was that he was extremely devoted\nto a lady who lived there\u{2014}a foreign lady\u{2014}a person older than\nhimself. Very few Americans\u{2014}indeed, I think none\u{2014}had ever\nseen this lady, about whom there were some singular stories. But\nWinterbourne had an old attachment for the little metropolis of\nCalvinism; he had been put to school there as a boy, and he had\nafterward gone to college there\u{2014}circumstances which had led\nto his forming a great many youthful friendships. Many of these\nhe had kept, and they were a source of great satisfaction to him.\nAfter knocking at his aunt\u{2019}s door and learning that she was\nD A I S Y M I L L E R\n3"
private let p9Text = "Nevertheless, he went back to live at Geneva, whence there\ncontinue to come the most contradictory accounts of his\nmotives of sojourn: a report that he is \u{201C}studying\u{201D} hard—an inti-\nmation that he is much interested in a very clever foreign lady.\nThe End\nD A I S Y M I L L E R\n75"

private func makeElement(
    pageNumber: Int,
    text: String
) -> AnyEquatableContentElement {
    let progression = Double(pageNumber - 1) / 9.0
    let loc = makeLocator(
        position: pageNumber,
        progression: progression,
        highlight: text
    ).copy(locations: { $0.fragments = ["page=\(pageNumber)"] })
    return TextContentElement(
        locator: loc,
        role: .body,
        segments: [TextContentElement.Segment(locator: loc, text: text)]
    ).equatable()
}

private let sampleElements: [AnyEquatableContentElement] = [
    makeElement(pageNumber: 2, text: p2Text),
    makeElement(pageNumber: 3, text: p3Text),
    makeElement(pageNumber: 4, text: p4Text),
    makeElement(pageNumber: 5, text: p5Text),
    makeElement(pageNumber: 6, text: p6Text),
    makeElement(pageNumber: 7, text: p7Text),
    makeElement(pageNumber: 8, text: p8Text),
    makeElement(pageNumber: 9, text: p9Text),
]

private func makeLocator(
    position: Int? = nil,
    pageFragment: Int? = nil,
    progression: Double? = nil,
    highlight: String? = nil
) -> Locator {
    baseLocator.copy(
        locations: {
            $0.position = position
            $0.progression = progression
            if let page = pageFragment {
                $0.fragments = ["page=\(page)"]
            }
        },
        text: {
            $0.highlight = highlight
        }
    )
}

private func makeIterator(
    start startLocator: Locator? = nil,
    positionOffset: Int = 0,
    totalProgressionRange: ClosedRange<Double>? = nil
) -> PDFResourceContentIterator {
    let data = Fixtures(path: "Publication/Services").data(at: "daisy-truncated.pdf")
    let resource = DataResource(data: data)
    let href = baseLocator.href
    return PDFResourceContentIterator(
        openDocument: { try await DefaultPDFDocumentFactory().open(resource: resource, at: href, password: nil) },
        resourceInfo: { PDFResourceContentIterator.ResourceInfo(positionOffset: positionOffset, totalProgressionRange: totalProgressionRange) },
        locator: startLocator ?? baseLocator
    )
}

// MARK: - Mock PDF Documents

private class MockPDFDocument: PDFDocumentTextProviding {
    private let texts: [String?]
    private(set) var requestedPageIndices: [Int] = []

    init(texts: [String?]) {
        self.texts = texts
    }

    func resetTracking() {
        requestedPageIndices = []
    }

    func identifier() async throws -> String? {
        nil
    }

    func pageCount() async throws -> Int {
        texts.count
    }

    func cover() async throws -> UIImage? {
        nil
    }

    func readingProgression() async throws -> ReadingProgression? {
        nil
    }

    func title() async throws -> String? {
        nil
    }

    func author() async throws -> String? {
        nil
    }

    func subject() async throws -> String? {
        nil
    }

    func keywords() async throws -> [String] {
        []
    }

    func tableOfContents() async throws -> [PDFOutlineNode] {
        []
    }

    func pageText(at pageIndex: Int) async throws -> String? {
        requestedPageIndices.append(pageIndex)
        return texts.getOrNil(pageIndex) ?? nil
    }
}

private class MockNonTextPDFDocument: PDFDocument {
    func identifier() async throws -> String? {
        nil
    }

    func pageCount() async throws -> Int {
        5
    }

    func cover() async throws -> UIImage? {
        nil
    }

    func readingProgression() async throws -> ReadingProgression? {
        nil
    }

    func title() async throws -> String? {
        nil
    }

    func author() async throws -> String? {
        nil
    }

    func subject() async throws -> String? {
        nil
    }

    func keywords() async throws -> [String] {
        []
    }

    func tableOfContents() async throws -> [PDFOutlineNode] {
        []
    }
}

private func makeIteratorFromMock(
    _ mock: MockPDFDocument,
    startLocator: Locator? = nil
) -> PDFResourceContentIterator {
    PDFResourceContentIterator(
        openDocument: { mock },
        resourceInfo: { PDFResourceContentIterator.ResourceInfo(positionOffset: 0, totalProgressionRange: nil) },
        locator: startLocator ?? Locator(href: "mock.pdf", mediaType: .pdf)
    )
}
