//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An entry of a ``Timeline``, such as a chapter.
///
/// As the ``id`` is a pre-order index, the same entry keeps its `id` in a
/// timeline rebuilt from the same table of contents.
@_spi(ExperimentalTimeline)
public struct TimelineItem: Identifiable, Hashable, Sendable {
    /// Title of an item.
    public enum Title: Hashable, Sendable {
        /// A title to display.
        case text(String)

        /// No title. Holds the 1-based number of the item's resource in the
        /// reading order, to display a title such as "Track 3".
        ///
        /// It counts all the resources, not only the untitled ones.
        case number(Int)
    }

    /// Index of the item in the pre-order traversal of its timeline, unique
    /// within the timeline.
    public let id: Int

    /// Title of the item.
    public let title: Title

    /// Link of the table of contents entry, or of the reading order resource
    /// for a generated item.
    ///
    /// Use it to jump to the item with `Navigator.go(to:)`.
    public let link: Link

    /// Start of the item, or `nil` when it could not be placed on the
    /// timeline.
    ///
    /// For example, when it references a resource outside the reading order,
    /// or starts before the previous item (going back).
    public let start: TimelinePosition?

    /// Exclusive end of the item.
    ///
    /// `nil` when the item has no ``start``, or when it ends at the end of a
    /// publication whose last resource duration is unknown.
    public let end: TimelinePosition?

    /// Items of the nested table of contents entries, in order.
    ///
    /// Their ranges are inside the range of this item, which owns the gap
    /// before its first placed child.
    public let children: [TimelineItem]

    package init(
        id: Int,
        title: Title,
        link: Link,
        start: TimelinePosition?,
        end: TimelinePosition?,
        children: [TimelineItem]
    ) {
        self.id = id
        self.title = title
        self.link = link
        self.start = start
        self.end = end
        self.children = children
    }
}
