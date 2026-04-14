//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared

/// Computes the current `Locator` and `NavigatorViewport` from the focused and
/// visible pages in a PDF document.
enum PDFViewportCalculator {
    /// Returns the position locator for the given 1-based page number, or
    /// `nil` when `currentResourceIndex` is out of bounds or no positions are
    /// available for the page.
    static func computeLocator(
        currentPageNumber: Int,
        currentResourceIndex: Int,
        readingOrder: [Link],
        positionsByReadingOrder: [[Locator]]
    ) -> Locator? {
        guard readingOrder.indices.contains(currentResourceIndex) else {
            return nil
        }

        let resourcePositions = positionsByReadingOrder.getOrNil(currentResourceIndex) ?? []
        return resourcePositions.getOrNil(currentPageNumber - 1)
    }

    /// Computes the locator and viewport for the currently visible PDF pages.
    ///
    /// - Parameters:
    ///   - currentPageNumber: 1-based page number of the focused page (used
    ///     for the locator).
    ///   - visiblePageNumbers: 1-based page numbers of the first and last
    ///     visible pages (inclusive). First equals last for a single visible
    ///     page.
    ///   - pageCount: Total number of pages in the PDF document.
    ///   - currentResourceIndex: Index into `readingOrder` for the loaded PDF.
    ///   - readingOrder: The publication's reading order links.
    ///   - positionsByReadingOrder: Positions grouped by reading-order index.
    ///     May be empty if positions are unavailable.
    /// - Returns: `(nil, nil)` when `currentResourceIndex` is out of bounds.
    static func compute(
        currentPageNumber: Int,
        visiblePageNumbers: ClosedRange<Int>,
        pageCount: Int,
        currentResourceIndex: Int,
        readingOrder: [Link],
        positionsByReadingOrder: [[Locator]]
    ) -> (locator: Locator?, viewport: NavigatorViewport?) {
        guard readingOrder.indices.contains(currentResourceIndex) else {
            return (nil, nil)
        }

        let resourcePositions = positionsByReadingOrder.getOrNil(currentResourceIndex) ?? []

        let locator = computeLocator(
            currentPageNumber: currentPageNumber,
            currentResourceIndex: currentResourceIndex,
            readingOrder: readingOrder,
            positionsByReadingOrder: positionsByReadingOrder
        )

        let firstPage = visiblePageNumbers.lowerBound
        let lastPage = visiblePageNumbers.upperBound

        // Intra-resource progression (0–1). The end of page N equals the start
        // of page N+1, so that consecutive viewports share the same boundary
        // value.
        let resourceProgressionLow = pageCount > 1 ? Double(firstPage - 1) / Double(pageCount - 1) : 0.0
        let resourceProgressionHigh = pageCount > 1 ? min(1.0, Double(lastPage) / Double(pageCount - 1)) : 1.0
        let resourceProgression = resourceProgressionLow ... resourceProgressionHigh

        let href = readingOrder[currentResourceIndex].url()

        // Map 1-based page numbers to positions (0-based index = page - 1).
        let positionRange: ClosedRange<Int>? = resourcePositions.isEmpty ? nil : {
            let firstPos = resourcePositions.getOrNil(firstPage - 1)?.locations.position
            let lastPos = resourcePositions.getOrNil(lastPage - 1)?.locations.position
            guard let fp = firstPos, let lp = lastPos, fp <= lp else { return nil }
            return fp ... lp
        }()

        let totalProgression = ViewportProgressionCalculator.totalProgressionRange(
            firstResource: (href: href, progression: resourceProgression),
            lastResource: (href: href, progression: resourceProgression),
            readingOrder: readingOrder,
            positionsByReadingOrder: positionsByReadingOrder
        ) ?? (resourceProgressionLow ... resourceProgressionHigh)

        let viewport = NavigatorViewport(
            resources: [
                NavigatorViewport.Resource(
                    href: href,
                    progression: resourceProgression
                ),
            ],
            progression: totalProgression,
            positions: positionRange
        )
        return (locator, viewport)
    }
}
