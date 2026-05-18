//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Resolves a PDF page number from a `Locator`.
enum PDFPageNumberResolver {
    /// Resolves the PDF page number from the given `locator`.
    ///
    /// The resolution strategy is, in order of priority:
    /// 1. A `page=N` fragment in the locator.
    /// 2. The locator's `position`, adjusted to be relative to the resource when
    ///    the publication contains multiple PDF files.
    /// 3. The locator's `progression`, mapped to a page using the pre-computed
    ///    positions list, or estimated from the total page count as a fallback.
    ///
    /// - Parameters:
    ///   - locator: The locator to resolve.
    ///   - readingOrderIndex: Index of the resource targeted by `locator`
    ///     in the reading order, or `nil` if not applicable.
    ///   - positionsByReadingOrder: Pre-computed positions grouped by reading
    ///     order index, or `nil` if unavailable.
    ///   - documentPageCount: Total page count of the PDF document, used as a
    ///     fallback when positions are unavailable.
    /// - Returns: The resolved 1-based page number, or `nil` if it cannot be
    ///   determined.
    static func resolve(
        from locator: Locator,
        readingOrderIndex: Int?,
        positionsByReadingOrder: [[Locator]]?,
        documentPageCount: Int?
    ) -> Int? {
        if let page = locator.locations.page {
            return page
        }

        if
            let position = locator.locations.position,
            let readingOrderIndex,
            let allPositions = positionsByReadingOrder
        {
            let pagesBeforeResource = allPositions.prefix(readingOrderIndex).reduce(0) { $0 + $1.count }
            let localPage = position - pagesBeforeResource
            if localPage >= 1 {
                return localPage
            }
        }

        if let progression = locator.locations.progression {
            if
                let readingOrderIndex,
                let resourcePositions = positionsByReadingOrder?.getOrNil(readingOrderIndex),
                !resourcePositions.isEmpty,
                let page = pageNumber(from: progression, in: resourcePositions)
            {
                return page
            }

            if let documentPageCount, documentPageCount > 0 {
                let progression = min(max(0.0, progression), 1.0)
                return min(documentPageCount, Int(floor(progression * Double(documentPageCount))) + 1)
            }
        }

        return nil
    }

    /// Resolves a page number from a `progression` by finding the last position
    /// whose progression is ≤ the given value, then reading its `page`
    /// fragment.
    private static func pageNumber(from progression: Double, in positions: [Locator]) -> Int? {
        guard !positions.isEmpty else {
            return nil
        }

        let pageLocator = positions.last {
            ($0.locations.progression ?? 0.0) <= progression
        } ?? positions.first

        return pageLocator?.locations.page
    }
}
