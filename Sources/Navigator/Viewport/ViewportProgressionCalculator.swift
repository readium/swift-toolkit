//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared

/// Computes total publication progression from resource-level progressions and
/// the publication's position list.
enum ViewportProgressionCalculator {
    /// Returns the visible total progression range across one or two visible
    /// resources, or `nil` when the resources cannot be found in the reading
    /// order or the position list is unavailable.
    ///
    /// Algorithm:
    ///   1. Find each resource's index in the reading order.
    ///   2. Derive the resource's total progression window:
    ///      `[resourceStart, nextResourceStart ?? 1.0]`.
    ///   3. Linearly interpolate the intra-resource progression within that
    ///      window to produce a global total progression value.
    ///   4. Return `lower...upper`, clamped so that `lower <= upper`.
    ///
    /// - Parameters:
    ///   - firstResource: The first (topmost) visible resource and its
    ///     intra-resource progression range. The lower bound is used for the
    ///     output range's lower bound.
    ///   - lastResource: The last (bottommost) visible resource and its
    ///     intra-resource progression range. The upper bound is used for the
    ///     output range's upper bound. May be the same as `firstResource`.
    ///   - readingOrder: The publication's reading order links.
    ///   - positionsByReadingOrder: Positions grouped by reading-order index.
    static func totalProgressionRange(
        firstResource: (href: AnyURL, progression: ClosedRange<Double>),
        lastResource: (href: AnyURL, progression: ClosedRange<Double>),
        readingOrder: [Link],
        positionsByReadingOrder: [[Locator]]
    ) -> ClosedRange<Double>? {
        guard
            let lower = totalProgression(
                for: firstResource.href,
                resourceProgression: firstResource.progression.lowerBound,
                readingOrder: readingOrder,
                positionsByReadingOrder: positionsByReadingOrder
            ),
            let upper = totalProgression(
                for: lastResource.href,
                resourceProgression: lastResource.progression.upperBound,
                readingOrder: readingOrder,
                positionsByReadingOrder: positionsByReadingOrder
            )
        else {
            return nil
        }

        // Guard against floating-point drift producing an invalid range.
        return min(lower, upper) ... max(lower, upper)
    }

    /// Maps an intra-resource progression (0.0–1.0) to a global total
    /// progression by linearly interpolating within the resource's global range.
    ///
    /// The resource range spans from the `totalProgression` of the resource's
    /// first position to the `totalProgression` of the next resource's first
    /// position (or 1.0 for the last resource).
    private static func totalProgression(
        for href: AnyURL,
        resourceProgression: Double,
        readingOrder: [Link],
        positionsByReadingOrder: [[Locator]]
    ) -> Double? {
        guard
            let index = readingOrder.firstIndexWithHREF(href),
            let resourceStart = positionsByReadingOrder.getOrNil(index)?
            .first?.locations.totalProgression
        else {
            return nil
        }

        let resourceEnd = positionsByReadingOrder.getOrNil(index + 1)?
            .first?.locations.totalProgression ?? 1.0

        return resourceStart + resourceProgression * (resourceEnd - resourceStart)
    }
}
