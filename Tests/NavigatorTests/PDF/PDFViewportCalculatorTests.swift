//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

enum PDFViewportCalculatorTests {
    // Layout used by most multi-resource tests:
    // 2 resources × 4 pages = 8 total positions.
    // Resource 0 total progression window: 0.0 … 0.5
    // Resource 1 total progression window: 0.5 … 1.0

    @Suite("Locator") struct Locator {
        // 1 resource, 4 pages, positions available.

        @Test("first page returns position 1")
        func locatorForFirstPage() {
            let locator = PDFViewportCalculator.computeLocator(
                currentPageNumber: 1,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: makePositions(resourceCount: 1, pagesPerResource: 4)
            )
            #expect(locator?.locations.position == 1)
        }

        @Test("last page returns last position")
        func locatorForLastPage() {
            let locator = PDFViewportCalculator.computeLocator(
                currentPageNumber: 4,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: makePositions(resourceCount: 1, pagesPerResource: 4)
            )
            #expect(locator?.locations.position == 4)
        }

        @Test("middle page returns its position")
        func locatorForMiddlePage() {
            let locator = PDFViewportCalculator.computeLocator(
                currentPageNumber: 2,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: makePositions(resourceCount: 1, pagesPerResource: 4)
            )
            #expect(locator?.locations.position == 2)
        }

        @Test("returns nil when no positions available")
        func locatorIsNilWhenNoPositions() {
            let locator = PDFViewportCalculator.computeLocator(
                currentPageNumber: 1,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: []
            )
            #expect(locator == nil)
        }

        @Test("returns nil when resource index is out of bounds")
        func locatorIsNilWhenOutOfBounds() {
            let locator = PDFViewportCalculator.computeLocator(
                currentPageNumber: 1,
                currentResourceIndex: 5,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: makePositions(resourceCount: 1, pagesPerResource: 4)
            )
            #expect(locator == nil)
        }
    }

    @Suite("Resource progression") struct ResourceProgression {
        // 1 resource, 4 pages. Progression formula:
        //   low  = (firstPage - 1) / pageCount
        //   high = lastPage / pageCount

        @Test("first page only — progression starts at 0")
        func firstPageOnly() {
            let (_, viewport) = PDFViewportCalculator.compute(
                currentPageNumber: 1,
                visiblePageNumbers: 1 ... 1,
                pageCount: 4,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: makePositions(resourceCount: 1, pagesPerResource: 4)
            )
            // low  = (1 - 1) / 4 = 0.0
            // high = 1 / 4 = 0.25
            #expect(viewport?.resources.first?.progression.lowerBound == 0.0)
            #expect(viewport?.resources.first?.progression.upperBound == 0.25)
        }

        @Test("last page only — progression ends at 1")
        func lastPageOnly() {
            let (_, viewport) = PDFViewportCalculator.compute(
                currentPageNumber: 4,
                visiblePageNumbers: 4 ... 4,
                pageCount: 4,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: makePositions(resourceCount: 1, pagesPerResource: 4)
            )
            // low  = (4 - 1) / 4 = 0.75
            // high = 4 / 4 = 1.0
            #expect(viewport?.resources.first?.progression == 0.75 ... 1.0)
        }

        @Test("all pages visible — full 0…1 range")
        func fullDocument() {
            let (_, viewport) = PDFViewportCalculator.compute(
                currentPageNumber: 1,
                visiblePageNumbers: 1 ... 4,
                pageCount: 4,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: makePositions(resourceCount: 1, pagesPerResource: 4)
            )
            #expect(viewport?.resources.first?.progression == 0.0 ... 1.0)
        }

        @Test("middle pages — progression is an interior range")
        func middlePages() {
            let (_, viewport) = PDFViewportCalculator.compute(
                currentPageNumber: 2,
                visiblePageNumbers: 2 ... 3,
                pageCount: 4,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: makePositions(resourceCount: 1, pagesPerResource: 4)
            )
            // low  = (2 - 1) / 4 = 0.25
            // high = 3 / 4 = 0.75
            #expect(viewport?.resources.first?.progression.lowerBound == 0.25)
            #expect(viewport?.resources.first?.progression.upperBound == 0.75)
        }

        @Test("single-page document — progression is always 0…1")
        func singlePageDocument() {
            let (_, viewport) = PDFViewportCalculator.compute(
                currentPageNumber: 1,
                visiblePageNumbers: 1 ... 1,
                pageCount: 1,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: makePositions(resourceCount: 1, pagesPerResource: 1)
            )
            #expect(viewport?.resources.first?.progression == 0.0 ... 1.0)
        }
    }

    @Suite("Viewport positions") struct ViewportPositions {
        // 1 resource, 4 pages.

        @Test("first page maps to first position")
        func firstPageMapsToFirstPosition() {
            let (_, viewport) = PDFViewportCalculator.compute(
                currentPageNumber: 1,
                visiblePageNumbers: 1 ... 1,
                pageCount: 4,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: makePositions(resourceCount: 1, pagesPerResource: 4)
            )
            #expect(viewport?.positions == 1 ... 1)
        }

        @Test("last page maps to last position")
        func lastPageMapsToLastPosition() {
            let (_, viewport) = PDFViewportCalculator.compute(
                currentPageNumber: 4,
                visiblePageNumbers: 4 ... 4,
                pageCount: 4,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: makePositions(resourceCount: 1, pagesPerResource: 4)
            )
            #expect(viewport?.positions == 4 ... 4)
        }

        @Test("multiple visible pages produce a position range")
        func multipleVisiblePages() {
            let (_, viewport) = PDFViewportCalculator.compute(
                currentPageNumber: 1,
                visiblePageNumbers: 1 ... 4,
                pageCount: 4,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: makePositions(resourceCount: 1, pagesPerResource: 4)
            )
            #expect(viewport?.positions == 1 ... 4)
        }

        @Test("positions is nil when positionsByReadingOrder is empty")
        func noPositionsAvailableReturnsNil() {
            let (_, viewport) = PDFViewportCalculator.compute(
                currentPageNumber: 1,
                visiblePageNumbers: 1 ... 1,
                pageCount: 4,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: []
            )
            #expect(viewport?.positions == nil)
        }
    }

    @Suite("Viewport progression") struct ViewportProgression {
        // 2 resources × 4 pages = 8 total positions.
        // Resource 0 total progression window: 0.0 … 0.5
        // Resource 1 total progression window: 0.5 … 1.0

        @Test("first page of document — lower bound is 0.0")
        func atStartOfDocument() {
            let (_, viewport) = PDFViewportCalculator.compute(
                currentPageNumber: 1,
                visiblePageNumbers: 1 ... 1,
                pageCount: 4,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, pagesPerResource: 4)
            )
            // resourceProgression = 0.0 … 0.25
            // totalProgression lower = 0.0 + 0.0  * 0.5 = 0.0
            // totalProgression upper = 0.0 + 0.25 * 0.5 = 0.125
            #expect(viewport?.progression.lowerBound == 0.0)
            #expect(viewport?.progression.upperBound == 0.125)
        }

        @Test("last page of first resource — upper bound is 0.5")
        func atEndOfFirstResource() {
            let (_, viewport) = PDFViewportCalculator.compute(
                currentPageNumber: 4,
                visiblePageNumbers: 4 ... 4,
                pageCount: 4,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, pagesPerResource: 4)
            )
            // resourceProgression = 0.75 … 1.0
            // totalProgression lower = 0.0 + 0.75 * 0.5 = 0.375
            // totalProgression upper = 0.0 + 1.0  * 0.5 = 0.5
            #expect(viewport?.progression == 0.375 ... 0.5)
        }

        @Test("last page of publication — upper bound is 1.0")
        func atEndOfPublication() {
            let (_, viewport) = PDFViewportCalculator.compute(
                currentPageNumber: 4,
                visiblePageNumbers: 4 ... 4,
                pageCount: 4,
                currentResourceIndex: 1,
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, pagesPerResource: 4)
            )
            // Resource 1, page 4/4 → resourceProgression = 0.75 … 1.0
            // totalProgression lower = 0.5 + 0.75 * 0.5 = 0.875
            // totalProgression upper = 0.5 + 1.0  * 0.5 = 1.0
            #expect(viewport?.progression == 0.875 ... 1.0)
        }

        @Test("falls back to resource progression when no positions available")
        func fallsBackToResourceProgressionWhenNoPositions() {
            let (_, viewport) = PDFViewportCalculator.compute(
                currentPageNumber: 1,
                visiblePageNumbers: 1 ... 2,
                pageCount: 4,
                currentResourceIndex: 0,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: []
            )
            // No positions → fallback = resourceProgression
            // low  = (1 - 1) / 4 = 0.0
            // high = 2 / 4 = 0.5
            #expect(viewport?.progression.lowerBound == 0.0)
            #expect(viewport?.progression.upperBound == 0.5)
        }
    }

    /// Both the locator's totalProgression and viewport.progression.lowerBound
    /// use the same N-slot formula — (page-1)/pageCount — so they agree.
    @Suite("Locator vs viewport progression") struct LocatorVsViewportProgression {
        @Test("locator totalProgression equals viewport lowerBound")
        func locatorAndViewportProgressionAgree() {
            // 1 resource, 4 pages.
            // Both locator and viewport use (page-1)/pageCount:
            //   page 1 → 0/4 = 0.0,  page 2 → 1/4 = 0.25,
            //   page 3 → 2/4 = 0.5,  page 4 → 3/4 = 0.75
            let positions = makePositions(resourceCount: 1, pagesPerResource: 4)
            let readingOrder = makeReadingOrder(count: 1)

            // Page 2: locator and viewport lowerBound both at 0.25.
            let (locator2, viewport2) = PDFViewportCalculator.compute(
                currentPageNumber: 2,
                visiblePageNumbers: 2 ... 2,
                pageCount: 4,
                currentResourceIndex: 0,
                readingOrder: readingOrder,
                positionsByReadingOrder: positions
            )
            #expect(locator2?.locations.totalProgression == 0.25)
            #expect(viewport2?.progression.lowerBound == 0.25)

            // Last page: locator and viewport lowerBound both at 0.75.
            let (locator4, viewport4) = PDFViewportCalculator.compute(
                currentPageNumber: 4,
                visiblePageNumbers: 4 ... 4,
                pageCount: 4,
                currentResourceIndex: 0,
                readingOrder: readingOrder,
                positionsByReadingOrder: positions
            )
            #expect(locator4?.locations.totalProgression == 0.75)
            #expect(viewport4?.progression.lowerBound == 0.75)
        }
    }

    @Suite("Nil result") struct NilResult {
        @Test("out-of-bounds resource index returns (nil, nil) from compute")
        func outOfBoundsResourceIndexReturnsNilPair() {
            let (locator, viewport) = PDFViewportCalculator.compute(
                currentPageNumber: 1,
                visiblePageNumbers: 1 ... 1,
                pageCount: 4,
                currentResourceIndex: 5,
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: makePositions(resourceCount: 1, pagesPerResource: 4)
            )
            #expect(locator == nil)
            #expect(viewport == nil)
        }
    }
}

// MARK: - Helpers

/// Builds a reading order of `count` links with hrefs "doc1.pdf", "doc2.pdf", …
private func makeReadingOrder(count: Int) -> [Link] {
    (1 ... count).map { Link(href: "doc\($0).pdf", mediaType: .pdf) }
}

/// Builds positions for `resourceCount` resources, each with `pagesPerResource` pages.
/// `totalProgression` is distributed evenly across the whole publication;
/// position numbers are 1-based and sequential.
private func makePositions(resourceCount: Int, pagesPerResource: Int) -> [[Locator]] {
    let total = resourceCount * pagesPerResource

    return (0 ..< resourceCount).map { r in
        (0 ..< pagesPerResource).map { p in
            let absoluteIndex = r * pagesPerResource + p
            return Locator(
                href: AnyURL(string: "doc\(r + 1).pdf")!,
                mediaType: .pdf,
                locations: .init(
                    progression: pagesPerResource > 1
                        ? Double(p) / Double(pagesPerResource - 1)
                        : 0.0,
                    totalProgression: Double(absoluteIndex) / Double(total),
                    position: absoluteIndex + 1
                )
            )
        }
    }
}
