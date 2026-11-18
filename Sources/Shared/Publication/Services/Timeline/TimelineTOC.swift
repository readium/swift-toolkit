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

    /// Depth of each entry, starting at 1 for the top level.
    let depths: [Int]

    /// Returns the entries from the top level down to `entry` itself, such
    /// as the chapter and then the section for a section.
    ///
    /// `entry` must be an entry of this table of contents.
    public func path(to entry: TimelineTOCEntry) -> [TimelineTOCEntry] {
        var path = [entry]
        var parentIndex = parentIndices[entry.id.index]
        while let index = parentIndex {
            path.append(allEntries[index])
            parentIndex = parentIndices[index]
        }
        return path.reversed()
    }

    /// Returns the index of the entry containing the positions from the start
    /// of the ranged entry `entryIndex`: itself, or its closest ranged
    /// ancestor within `maxDepth`.
    func containingEntryIndex(from entryIndex: Int, maxDepth: Int?) -> Int? {
        var containingIndex: Int? = entryIndex
        while let currentIndex = containingIndex, !isRanged(currentIndex) || !isWithin(currentIndex, maxDepth: maxDepth) {
            containingIndex = parentIndices[currentIndex]
        }
        return containingIndex
    }

    private func isRanged(_ entryIndex: Int) -> Bool {
        allEntries[entryIndex].start != nil
    }

    private func isWithin(_ entryIndex: Int, maxDepth: Int?) -> Bool {
        maxDepth.map { depths[entryIndex] <= $0 } ?? true
    }
}
