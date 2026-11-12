//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// The table of contents of a publication laid out on its reading order, to
/// answer questions such as "which chapter am I in?", "what's the next
/// chapter?" or "how long is this chapter?".
///
/// The reading order forms a continuous line from the start of the
/// publication to its end, made of the duration of each resource for an
/// audiobook. A ``TimelinePosition`` is a point on this line.
///
/// Its ``toc`` is a tree of ``TimelineTOCEntry`` mirroring the table of
/// contents. Each entry has a range on the line:
///
/// - It starts where its link points, such as `t2.mp3#t=60`.
/// - It ends at the start of the next placed entry after its subtree, or at
///   the end of the publication. A parent therefore contains its children,
///   and owns the gap before its first child.
///
/// An entry that cannot be placed keeps its place in the tree without a
/// range: its link points outside the reading order, or before the start of
/// the previous placed entry.
///
/// The ``segments(maxDepth:)`` cover the reading order, including outside
/// any entry, such as before the first one or in a publication without a
/// table of contents.
@_spi(ExperimentalTimeline)
public struct Timeline: Sendable {
    /// Source of a ``TimelineTOCEntry``.
    public struct Node: Sendable {
        public let title: String
        public let link: Link
        public let children: [Node]

        public init(title: String, link: Link, children: [Node] = []) {
            self.title = title
            self.link = link
            self.children = children
        }
    }

    /// Table of contents laid out on the reading order.
    public let toc: TimelineTOC

    private let resolver: any TimelinePositionResolver

    /// Indices of the entries with a range, in pre-order, which is also the
    /// order of their starts.
    private let rangedIndices: [Int]

    /// Start of each reading order resource.
    private let resourceStarts: [ResourceStart]

    private struct ResourceStart: Sendable {
        let link: Link
        let position: TimelinePosition
    }

    /// Start of a range of ``segments(maxDepth:)``.
    private struct Boundary {
        let start: TimelinePosition

        /// Ranged entry starting the range, or `nil` at the start of a
        /// resource continuing the previous range.
        let rangedIndex: Int?

        /// Link to the start, when the entry of the range does not start
        /// there: of the resource starting there, or else of the first
        /// ranged entry starting there.
        let link: Link
    }

    public init(nodes: [Node], resolver: any TimelinePositionResolver) {
        // Flattens the nodes in pre-order.
        var flatNodes: [Node] = []
        var parentIndices: [Int?] = []
        var depths: [Int] = []
        var childIndices: [[Int]] = []
        // Index following the subtree of each node.
        var subtreeEnds: [Int] = []

        @discardableResult
        func flatten(_ node: Node, parentIndex: Int?, depth: Int) -> Int {
            let nodeIndex = flatNodes.count
            flatNodes.append(node)
            parentIndices.append(parentIndex)
            depths.append(depth)
            childIndices.append([])
            subtreeEnds.append(nodeIndex)
            for child in node.children {
                childIndices[nodeIndex].append(flatten(child, parentIndex: nodeIndex, depth: depth + 1))
            }
            subtreeEnds[nodeIndex] = flatNodes.count
            return nodeIndex
        }

        let topLevelIndices = nodes.map { flatten($0, parentIndex: nil, depth: 1) }

        // Places the nodes in pre-order. A node starting before the last
        // placed one is left without a range.
        var starts: [TimelinePosition?] = []
        var rangedIndices: [Int] = []
        var lastStart: TimelinePosition?
        for (nodeIndex, node) in flatNodes.enumerated() {
            var start = resolver.position(of: node.link)
            if let position = start, let lastStart, position.isBefore(lastStart) {
                start = nil
            }
            starts.append(start)
            if let start {
                rangedIndices.append(nodeIndex)
                lastStart = start
            }
        }

        // Start of the first ranged entry from each index.
        var nextStarts = [TimelinePosition?](repeating: nil, count: flatNodes.count + 1)
        for nodeIndex in flatNodes.indices.reversed() {
            nextStarts[nodeIndex] = starts[nodeIndex] ?? nextStarts[nodeIndex + 1]
        }

        // Builds the entries from the leaves, as children follow their
        // parent in pre-order.
        var allEntries = [TimelineTOCEntry?](repeating: nil, count: flatNodes.count)
        for (nodeIndex, node) in flatNodes.enumerated().reversed() {
            let start = starts[nodeIndex]
            let end = start.flatMap { start in
                // An entry can start past the known end of the publication.
                nextStarts[subtreeEnds[nodeIndex]] ?? resolver.end.map { $0.isBefore(start) ? start : $0 }
            }
            allEntries[nodeIndex] = TimelineTOCEntry(
                id: TimelineTOCEntry.ID(index: nodeIndex),
                title: node.title,
                link: node.link,
                start: start,
                end: end,
                length: start.flatMap { start in end.flatMap { resolver.length(from: start, to: $0) } },
                children: childIndices[nodeIndex].map { allEntries[$0]! }
            )
        }

        let builtEntries = allEntries.map { $0! }
        toc = TimelineTOC(
            entries: topLevelIndices.map { builtEntries[$0] },
            allEntries: builtEntries,
            parentIndices: parentIndices,
            depths: depths
        )
        self.resolver = resolver
        self.rangedIndices = rangedIndices
        resourceStarts = resolver.readingOrder.enumerated().map { index, link in
            ResourceStart(link: link, position: resolver.bounds(ofResourceAt: index).start)
        }
    }

    /// Returns the position of `locator` on the timeline, or `nil` when it is
    /// outside the reading order.
    public func position(of locator: Locator) -> TimelinePosition? {
        resolver.position(of: locator)
    }

    /// Returns the length between `start` and `end`, negative when `end` is
    /// before `start`, or `nil` when the length of a resource between them
    /// is unknown.
    public func length(from start: TimelinePosition, to end: TimelinePosition) -> TimelineLength? {
        resolver.length(from: start, to: end)
    }

    /// Returns the segments covering the reading order, one after another.
    ///
    /// The entry of a segment is the deepest one containing its positions,
    /// within `maxDepth`. Outside any entry, such as before the first one,
    /// there is one segment without entry per reading order resource.
    ///
    /// - Parameter maxDepth: Ignores the entries deeper than this depth: their
    ///   positions are in the segment of their closest ancestor within it.
    ///   The top level is 1.
    public func segments(maxDepth: Int? = nil) -> TimelineSegments {
        // Each ranged entry starts a range up to the next boundary, inside
        // the deepest entry containing it within `maxDepth`. The start of
        // each resource is a boundary too, so that a range without entry
        // stays in its resource.
        var boundaries: [Boundary] = []
        var resourceIndex = 0
        func addResourceStarts(upTo position: TimelinePosition?) {
            while resourceIndex < resourceStarts.count {
                let resourceStart = resourceStarts[resourceIndex]
                guard position.map({ !$0.isBefore(resourceStart.position) }) ?? true else {
                    return
                }
                boundaries.append(Boundary(start: resourceStart.position, rangedIndex: nil, link: resourceStart.link))
                resourceIndex += 1
            }
        }
        for rangedIndex in rangedIndices {
            let entry = toc.allEntries[rangedIndex]
            let start = entry.start!
            addResourceStarts(upTo: start)
            // Takes the link of a resource, or of a ranged entry, starting
            // there first.
            let link = boundaries.last.flatMap { $0.start.isAt(start) ? $0.link : nil } ?? entry.link
            boundaries.append(Boundary(start: start, rangedIndex: rangedIndex, link: link))
        }
        addResourceStarts(upTo: nil)

        var segments: [TimelineSegment] = []
        // Entry of the current range.
        var currentEntryIndex: Int?
        for (index, boundary) in boundaries.enumerated() {
            if let rangedIndex = boundary.rangedIndex {
                currentEntryIndex = toc.containingEntryIndex(from: rangedIndex, maxDepth: maxDepth)
            }
            let start = boundary.start
            let end = index + 1 < boundaries.count ? boundaries[index + 1].start : resolver.end
            guard end.map({ start.isBefore($0) }) ?? true else {
                continue
            }

            // Merges the consecutive ranges of an entry, such as those of the
            // entries deeper than `maxDepth`, and the ranges without entry of
            // a resource.
            if
                let last = segments.last,
                last.tocEntry?.id.index == currentEntryIndex,
                currentEntryIndex != nil || last.start.readingOrderIndex == start.readingOrderIndex
            {
                segments[segments.count - 1] = TimelineSegment(tocEntry: last.tocEntry, link: last.link, start: last.start, end: end)
            } else {
                let entry = currentEntryIndex.map { toc.allEntries[$0] }
                let link = entry.flatMap { $0.start?.isAt(start) == true ? $0.link : nil } ?? boundary.link
                segments.append(TimelineSegment(tocEntry: entry, link: link, start: start, end: end))
            }
        }

        return TimelineSegments(segments: segments, resolver: resolver)
    }
}
