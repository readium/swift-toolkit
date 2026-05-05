//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

enum PDFPageNumberResolverTests {
    struct PageFragment {
        @Test func resolves() {
            let page = resolve(locator: makeLocator(fragments: ["foo=1&page=42"]))
            #expect(page == 42)
        }

        @Test func takesPriorityOverPosition() {
            let page = resolve(
                locator: makeLocator(fragments: ["page=7"], position: 3),
                readingOrderIndex: 0,
                positionsByReadingOrder: [makePositions(count: 10)]
            )
            #expect(page == 7)
        }
    }

    struct Position {
        @Test func resolvesInSinglePDFPublication() {
            let page = resolve(
                locator: makeLocator(position: 3),
                readingOrderIndex: 0,
                positionsByReadingOrder: [makePositions(count: 5)]
            )
            #expect(page == 3)
        }

        @Test func resolvesRelativeToResourceInMultiPDFPublication() {
            // Resource 0: 5 pages, resource 1: 3 pages. Global position 7 → local page 2.
            let page = resolve(
                locator: makeLocator(position: 7),
                readingOrderIndex: 1,
                positionsByReadingOrder: [makePositions(count: 5), makePositions(count: 3)]
            )
            #expect(page == 2)
        }

        @Test func fallsThroughWhenLocalPageIsOutOfBounds() {
            // position=1 with 5 pages before the resource → localPage = -4, falls through to nil.
            let page = resolve(
                locator: makeLocator(position: 1),
                readingOrderIndex: 1,
                positionsByReadingOrder: [makePositions(count: 5), makePositions(count: 3)]
            )
            #expect(page == nil)
        }

        @Test func fallsThroughWhenReadingOrderIndexIsNil() {
            let page = resolve(
                locator: makeLocator(position: 3),
                readingOrderIndex: nil,
                positionsByReadingOrder: [makePositions(count: 5)]
            )
            #expect(page == nil)
        }
    }

    struct Progression {
        @Test func resolvesUsingPositionsList() {
            let positions: [[Locator]] = [[
                makeLocator(fragments: ["page=1"], progression: 0.0, position: 1),
                makeLocator(fragments: ["page=2"], progression: 0.5, position: 2),
                makeLocator(fragments: ["page=3"], progression: 1.0, position: 3),
            ]]
            let page = resolve(
                locator: makeLocator(progression: 0.6),
                readingOrderIndex: 0,
                positionsByReadingOrder: positions
            )
            #expect(page == 2)
        }

        @Test func resolvesUsingDocumentPageCountFallback() {
            let page = resolve(
                locator: makeLocator(progression: 0.55),
                readingOrderIndex: nil,
                positionsByReadingOrder: nil,
                documentPageCount: 10
            )
            #expect(page == 6)
        }

        @Test func clampsFallbackProgressionBelowZero() {
            let page = resolve(
                locator: makeLocator(progression: -0.5),
                documentPageCount: 10
            )
            #expect(page == 1)
        }

        @Test func clampsFallbackProgressionAboveOne() {
            let page = resolve(
                locator: makeLocator(progression: 1.5),
                documentPageCount: 10
            )
            #expect(page == 10)
        }

        @Test func fallsThroughWhenReadingOrderIndexIsNilAndNoDocumentPageCount() {
            let positions: [[Locator]] = [[
                makeLocator(fragments: ["page=1"], progression: 0.0, position: 1),
            ]]
            let page = resolve(
                locator: makeLocator(progression: 0.5),
                readingOrderIndex: nil,
                positionsByReadingOrder: positions
            )
            #expect(page == nil)
        }
    }

    struct ReturnsNil {
        @Test func whenNoLocationInformationIsAvailable() {
            let page = resolve(locator: makeLocator())
            #expect(page == nil)
        }

        @Test func whenDocumentPageCountIsZero() {
            let page = resolve(
                locator: makeLocator(progression: 0.5),
                documentPageCount: 0
            )
            #expect(page == nil)
        }
    }
}

// MARK: - Helpers

private func resolve(
    locator: Locator,
    readingOrderIndex: Int? = nil,
    positionsByReadingOrder: [[Locator]]? = nil,
    documentPageCount: Int? = nil
) -> Int? {
    PDFPageNumberResolver.resolve(
        from: locator,
        readingOrderIndex: readingOrderIndex,
        positionsByReadingOrder: positionsByReadingOrder,
        documentPageCount: documentPageCount
    )
}

private func makeLocator(
    fragments: [String] = [],
    progression: Double? = nil,
    position: Int? = nil
) -> Locator {
    Locator(
        href: AnyURL(string: "doc.pdf")!,
        mediaType: .pdf,
        locations: .init(fragments: fragments, progression: progression, position: position)
    )
}

private func makePositions(count: Int) -> [Locator] {
    (1 ... count).map { i in
        makeLocator(
            fragments: ["page=\(i)"],
            progression: count > 1 ? Double(i - 1) / Double(count - 1) : 0.0,
            position: i
        )
    }
}
