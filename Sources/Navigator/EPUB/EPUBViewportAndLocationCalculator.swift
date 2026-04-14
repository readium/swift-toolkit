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
    ) async -> (locator: Locator?, viewport: NavigatorViewport) {
        let firstIndex = readingOrderIndices.lowerBound
        let lastIndex = readingOrderIndices.upperBound
        let firstProgressionInFirstResource = min(max(progression(firstIndex).lowerBound, 0.0), 1.0)
        let lastProgressionInLastResource = min(max(progression(lastIndex).upperBound, 0.0), 1.0)

        let visibleResources: [NavigatorViewport.Resource] = readingOrderIndices
            .map { index in
                NavigatorViewport.Resource(
                    href: readingOrder[index].url(),
                    progression: progression(index)
                )
            }

        let link = readingOrder[firstIndex]
        let locator: Locator?
        var positions: ClosedRange<Int>? = nil

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

            // Compute the total progression range by linearly interpolating
            // each resource-level progression within the resource's global
            // range. The lower bound becomes the locator's totalProgression.
            let firstHref = readingOrder[firstIndex].url()
            let lastHref = readingOrder[lastIndex].url()
            let totalProgressionRange = ViewportProgressionCalculator.totalProgressionRange(
                firstResource: (href: firstHref, progression: progression(firstIndex)),
                lastResource: (href: lastHref, progression: progression(lastIndex)),
                readingOrder: readingOrder,
                positionsByReadingOrder: positionsByReadingOrder
            ) ?? (firstProgressionInFirstResource ... firstProgressionInFirstResource)

            // Build the locator from the nearest position, then override
            // progression fields with the actual continuous scroll values.
            locator = positionsOfFirstResource[firstPositionIndex].copy(
                title: tableOfContentsTitleByHref[link.url()],
                locations: {
                    $0.progression = firstProgressionInFirstResource
                    $0.totalProgression = totalProgressionRange.lowerBound
                }
            )

            if
                let firstPosition = locator?.locations.position,
                let lastPosition = positionsOfLastResource[lastPositionIndex].locations.position
            {
                positions = firstPosition ... lastPosition
            }

            let viewport = NavigatorViewport(
                resources: visibleResources,
                progression: totalProgressionRange,
                positions: positions
            )
            return (locator, viewport)

        } else {
            locator = await fallbackLocator(link)?.copy(
                locations: { $0.progression = firstProgressionInFirstResource }
            )

            let fallbackProgression = locator?.locations.totalProgression
                .map { $0 ... $0 } ?? 0.0 ... 0.0

            let viewport = NavigatorViewport(
                resources: visibleResources,
                progression: fallbackProgression,
                positions: nil
            )
            return (locator, viewport)
        }
    }
}
