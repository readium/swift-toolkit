//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// The table of contents of a ``Timeline``, as a tree of ``TimelineTOCEntry``.
///
/// Each entry has a range on the timeline, from where its link points, unless
/// it cannot be placed on the reading order.
@_spi(ExperimentalTimeline)
public struct TimelineTOC: Sendable {
    /// Top-level entries.
    public let entries: [TimelineTOCEntry]

    /// Whether the table of contents has no entries.
    public var isEmpty: Bool {
        entries.isEmpty
    }

    /// All the entries, in pre-order.
    let allEntries: [TimelineTOCEntry]

    /// Index of the parent of each entry.
    let parentIndices: [Int?]

    /// Returns the entries from the top level down to `entry` itself, such
    /// as the chapter and then the section for a section.
    ///
    /// `entry` must be an entry of this table of contents.
    public func path(to entry: TimelineTOCEntry) -> [TimelineTOCEntry] {
        var path = [entry]
        var parentIndex = parentIndices[entry.id.index]
        while let index = parentIndex {
            path.insert(allEntries[index], at: 0)
            parentIndex = parentIndices[index]
        }
        return path
    }
}
