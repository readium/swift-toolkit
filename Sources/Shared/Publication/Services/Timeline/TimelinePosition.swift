//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A position on a ``Timeline``.
///
/// A position is located by its reading order index and its offset. The other
/// properties are derived from these two.
@_spi(ExperimentalTimeline)
public struct TimelinePosition: Hashable, Sendable {
    /// Index of the resource in the reading order.
    public let readingOrderIndex: Int

    /// Offset in the resource, in a unit chosen by the resolver, such as
    /// seconds or a scroll progression.
    ///
    /// Only meaningful to compare positions of the same resource.
    public let offset: Double

    /// Where the position stands in the publication, in its natural unit.
    ///
    /// `nil` when the length of a preceding resource is unknown.
    public let coordinate: TimelineCoordinate?

    /// Progression in the resource, or `nil` when its length is unknown.
    ///
    /// Between 0 and 1, unless the position is past the known end of the
    /// resource.
    public let progression: Double?

    /// Progression in the publication, or `nil` when the length of a
    /// resource is unknown.
    ///
    /// Between 0 and 1, unless the position is past the known end of the
    /// publication.
    public let totalProgression: Double?

    public init(
        readingOrderIndex: Int,
        offset: Double,
        coordinate: TimelineCoordinate? = nil,
        progression: Double? = nil,
        totalProgression: Double? = nil
    ) {
        self.readingOrderIndex = readingOrderIndex
        self.offset = offset
        self.coordinate = coordinate
        self.progression = progression
        self.totalProgression = totalProgression
    }

    /// Returns whether this position comes before `other` on the timeline,
    /// ordering by reading order index, then by offset.
    ///
    /// Unlike `==`, this ordering ignores the derived properties: two
    /// positions can differ while neither comes before the other. This is why
    /// `TimelinePosition` is not `Comparable`.
    public func isBefore(_ other: TimelinePosition) -> Bool {
        (readingOrderIndex, offset) < (other.readingOrderIndex, other.offset)
    }
}

/// Where a position stands in a publication, in its natural unit.
///
/// The end of an item or of the publication is exclusive: one past its last
/// page or position, or the time where it stops.
@_spi(ExperimentalTimeline)
public enum TimelineCoordinate: Hashable, Sendable {
    /// Time from the start of the publication, in seconds.
    case time(TimeInterval)

    /// Page number, starting at 1.
    case page(Int)

    /// Position in the positions list of the publication, starting at 1.
    case position(Int)
}
