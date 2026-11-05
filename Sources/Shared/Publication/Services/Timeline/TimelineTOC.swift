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

    /// All the entries, indexed by their ID.
    let allEntries: [TimelineTOCEntry]

    /// ID of the parent of each entry.
    let parentIDs: [Int?]

    /// Returns the entries from the top level down to `entry` itself, such
    /// as the chapter and then the section for a section.
    ///
    /// `entry` must be an entry of this table of contents.
    public func path(to entry: TimelineTOCEntry) -> [TimelineTOCEntry] {
        var path = [entry]
        var parentID = parentIDs[entry.id]
        while let id = parentID {
            path.insert(allEntries[id], at: 0)
            parentID = parentIDs[id]
        }
        return path
    }
}
