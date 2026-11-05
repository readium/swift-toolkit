//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An entry of the ``TimelineTOC``.
///
/// As the ``id`` is a pre-order index, the same entry keeps its `id` in a
/// timeline rebuilt from the same table of contents.
@_spi(ExperimentalTimeline)
public struct TimelineTOCEntry: Identifiable, Hashable, Sendable {
    /// Title of an entry.
    public enum Title: Hashable, Sendable {
        /// A title to display.
        case text(String)

        /// No title. Holds the 1-based number of the entry's resource in the
        /// reading order, to display a title such as "Track 3".
        ///
        /// It counts all the resources, not only the untitled ones.
        case number(Int)
    }

    /// Index of the entry in the pre-order traversal of its table of
    /// contents, unique within the timeline.
    public let id: Int

    /// Title of the entry.
    public let title: Title

    /// Link of the entry in the table of contents, or of the reading order
    /// resource for a generated entry.
    ///
    /// Use it to jump to the entry with `Navigator.go(to:)`.
    public let link: Link

    /// Start of the entry, or `nil` when it could not be placed on the
    /// timeline.
    ///
    /// For example, when it references a resource outside the reading order,
    /// or starts before the previous entry (going back).
    public let start: TimelinePosition?

    /// Exclusive end of the entry.
    ///
    /// `nil` when the entry has no ``start``, or when it ends at the end of a
    /// publication whose last resource length is unknown.
    public let end: TimelinePosition?

    /// Length of the entry, from its ``start`` to its ``end``.
    ///
    /// The length of a parent covers its children. `nil` when the entry has
    /// no ``end``, or when it continues past a resource of unknown length.
    public let length: TimelineLength?

    /// Nested entries, in order.
    ///
    /// Their ranges are inside the range of this entry, which owns the gap
    /// before its first placed child.
    public let children: [TimelineTOCEntry]

    package init(
        id: Int,
        title: Title,
        link: Link,
        start: TimelinePosition?,
        end: TimelinePosition?,
        length: TimelineLength?,
        children: [TimelineTOCEntry]
    ) {
        self.id = id
        self.title = title
        self.link = link
        self.start = start
        self.end = end
        self.length = length
        self.children = children
    }
}

/// Length on a ``Timeline``, such as of a ``TimelineTOCEntry`` or between two
/// positions, in the natural unit of its publication.
///
/// Between two positions, it is negative when the second one is before the
/// first one.
@_spi(ExperimentalTimeline)
public enum TimelineLength: Hashable, Sendable {
    /// Duration, in seconds.
    case duration(TimeInterval)

    /// Number of pages.
    case pages(Int)

    /// Number of positions in the positions list of the publication.
    case positions(Int)

    /// Duration in seconds, or `nil` when the length is counted in pages or
    /// positions.
    public var seconds: TimeInterval? {
        switch self {
        case let .duration(seconds): seconds
        case .pages, .positions: nil
        }
    }

    /// Number of pages or positions, or `nil` when the length is a duration.
    public var count: Int? {
        switch self {
        case let .pages(count), let .positions(count): count
        case .duration: nil
        }
    }
}
