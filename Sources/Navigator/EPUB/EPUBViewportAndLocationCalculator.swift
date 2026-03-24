//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Computes the current `Locator` and `Viewport` from a spread's visible
/// progressions and the publication's position list.
enum EPUBViewportAndLocationCalculator {
    /// Computes the locator and viewport for the currently visible spread.
    ///
    /// - Parameters:
    ///   - readingOrderIndices: Closed range of reading-order indices visible
    ///     in the spread (single value for reflowable, two values for FXL
    ///     double spreads).
    ///   - progression: Returns the visible scroll progression range (0–1)
    ///     for a given reading-order index. For fixed-layout resources this
    ///     is always `0...1`.
    ///   - readingOrder: The publication's reading order links.
    ///   - positionsByReadingOrder: Positions grouped by reading-order index.
    ///     May be empty if the publication has no positions.
    ///   - tableOfContentsTitleByHref: Mapping from resource URL to its table-
    ///     of-contents title, used to populate `Locator.title`.
    ///   - fallbackLocator: Called with the first visible link when no
    ///     positions are available; should return a basic locator for that
    ///     link (e.g. from `Publication.locate(_:)`).
    static func compute(
        readingOrderIndices: ClosedRange<Int>,
        progression: (Int) -> ClosedRange<Double>,
        readingOrder: [Link],
        positionsByReadingOrder: [[Locator]],
        tableOfContentsTitleByHref: [AnyURL: String],
        fallbackLocator: (Link) async -> Locator?
    ) async -> (locator: Locator?, viewport: EPUBNavigatorViewController.Viewport) {
        let visibleReadingOrder: [(index: Int, href: AnyURL)] = readingOrderIndices
            .map { ($0, readingOrder[$0].url()) }

        var viewport = EPUBNavigatorViewController.Viewport(
            readingOrder: visibleReadingOrder.map(\.href),
            progressions: visibleReadingOrder.reduce(into: [:]) { acc, i in
                acc[i.href] = progression(i.index)
            },
            positions: nil
        )

        let firstIndex = readingOrderIndices.lowerBound
        let lastIndex = readingOrderIndices.upperBound
        let firstProgressionInFirstResource = min(max(progression(firstIndex).lowerBound, 0.0), 1.0)
        let lastProgressionInLastResource = min(max(progression(lastIndex).upperBound, 0.0), 1.0)

        let link = readingOrder[firstIndex]
        let locator: Locator?

        if
            // The positions are not always available, for example a Readium
            // WebPub doesn't have any unless a Publication Positions Web
            // Service is provided.
            let positionsOfFirstResource = positionsByReadingOrder.getOrNil(firstIndex),
            let positionsOfLastResource = positionsByReadingOrder.getOrNil(lastIndex),
            !positionsOfFirstResource.isEmpty,
            !positionsOfLastResource.isEmpty
        {
            // Map the resource progression (0–1) to a position index using
            // ceil, so the reported position advances as soon as the reader
            // enters it. This pairs with lastPositionIndex which uses
            // ceil(x) - 1 to find the last fully-entered position.
            let firstPositionIndex = Int(ceil(
                firstProgressionInFirstResource * Double(positionsOfFirstResource.count - 1)
            ))
            let lastPositionIndex: Int = (lastProgressionInLastResource == 1.0)
                ? positionsOfLastResource.count - 1
                : max(
                    // In a single-resource spread, clamp against firstPositionIndex
                    // to prevent an invalid lastPositionIndex < firstPositionIndex
                    // range. In a two-resource spread the two indices are into
                    // different arrays, so clamp against 0 instead.
                    firstIndex == lastIndex ? firstPositionIndex : 0,
                    Int(ceil(lastProgressionInLastResource * Double(positionsOfLastResource.count - 1))) - 1
                )

            // Compute a continuous totalProgression by linearly interpolating
            // the resource-level progression within the resource's global
            // range. The resource's range spans from the totalProgression of
            // its first position to the totalProgression of the next resource's
            // first position (or 1.0 for the last resource).
            let resourceTotalProgressionStart = positionsOfFirstResource.first?.locations.totalProgression ?? 0.0
            let resourceTotalProgressionEnd = positionsByReadingOrder.getOrNil(firstIndex + 1)?
                .first?.locations.totalProgression ?? 1.0
            let continuousTotalProgression =
                resourceTotalProgressionStart
                    + firstProgressionInFirstResource
                    * (resourceTotalProgressionEnd - resourceTotalProgressionStart)

            // Build the locator from the nearest position, then override
            // progression fields with the actual continuous scroll values.
            locator = positionsOfFirstResource[firstPositionIndex].copy(
                title: tableOfContentsTitleByHref[link.url()],
                locations: {
                    $0.progression = firstProgressionInFirstResource
                    $0.totalProgression = continuousTotalProgression
                }
            )

            if
                let firstPosition = locator?.locations.position,
                let lastPosition = positionsOfLastResource[lastPositionIndex].locations.position
            {
                viewport.positions = firstPosition ... lastPosition
            }

        } else {
            locator = await fallbackLocator(link)?.copy(
                locations: { $0.progression = firstProgressionInFirstResource }
            )
        }

        return (locator, viewport)
    }
}
