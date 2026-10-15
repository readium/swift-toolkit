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

    /// Offset in the resource.
    public let offset: TimelineOffset

    /// Offset from the start of the publication, or `nil` when the duration of
    /// a preceding resource is unknown.
    public let totalOffset: TimelineOffset?

    /// Progression in the resource, or `nil` when its duration is unknown.
    ///
    /// Between 0 and 1, unless the position is past the known end of the
    /// resource.
    public let progression: Double?

    /// Progression in the publication, or `nil` when the duration of a
    /// resource is unknown.
    ///
    /// Between 0 and 1, unless the position is past the known end of the
    /// publication.
    public let totalProgression: Double?

    package init(
        readingOrderIndex: Int,
        offset: TimelineOffset,
        totalOffset: TimelineOffset? = nil,
        progression: Double? = nil,
        totalProgression: Double? = nil
    ) {
        self.readingOrderIndex = readingOrderIndex
        self.offset = offset
        self.totalOffset = totalOffset
        self.progression = progression
        self.totalProgression = totalProgression
    }

    /// Returns whether this position comes before `other` on the timeline,
    /// ordering by reading order index, then by offset.
    func isBefore(_ other: TimelinePosition) -> Bool {
        (readingOrderIndex, offset) < (other.readingOrderIndex, other.offset)
    }
}

/// An offset in a resource, or from the start of a publication.
@_spi(ExperimentalTimeline)
public enum TimelineOffset: Comparable, Hashable, Sendable {
    /// A time offset, in seconds.
    case seconds(TimeInterval)
}
