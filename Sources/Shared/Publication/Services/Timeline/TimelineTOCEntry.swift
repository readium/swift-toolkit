//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An entry of the ``TimelineTOC``.
@_spi(ExperimentalTimeline)
public struct TimelineTOCEntry: Identifiable, Hashable, Sendable {
    /// Identifier of an entry, unique within its timeline.
    ///
    /// The same entry keeps its ID in a timeline rebuilt from the same table
    /// of contents.
    public struct ID: Hashable, Sendable {
        /// Index of the entry in the pre-order traversal of its table of
        /// contents.
        package let index: Int

        package init(index: Int) {
            self.index = index
        }
    }

    /// Identifier of the entry.
    public let id: ID

    /// Title of the entry.
    public let title: String

    /// Link of the entry in the table of contents.
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
        id: ID,
        title: String,
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
