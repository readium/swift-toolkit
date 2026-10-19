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
/// A timeline is a tree of ``TimelineItem`` mirroring the table of contents.
/// Each item has a range on the line:
///
/// - It starts where the link of its entry points, such as `t2.mp3#t=60`.
/// - It ends at the start of the next placed item after its subtree, or at
///   the end of the publication. A parent therefore contains its children,
///   and owns the gap before its first child.
///
/// An item that cannot be placed keeps its place in the tree without a
/// range: its link points outside the reading order, or before the start of
/// the previous placed item.
///
/// Without a table of contents, a timeline can be generated with one item per
/// reading order resource.
///
/// To display the current chapter in a running header, locate the
/// navigator's location each time it changes, and update the header when
/// the `id` of the item changes:
///
/// ```swift
/// func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
///     let chapter = timeline.locate(locator, maxDepth: 1)
///     if chapter?.id != currentChapter?.id {
///         currentChapter = chapter
///         updateHeader()
///     }
/// }
/// ```
@_spi(ExperimentalTimeline)
public struct Timeline: Sendable {
    /// Source of a ``TimelineItem``.
    public struct Node: Sendable {
        public let title: TimelineItem.Title
        public let link: Link
        public let children: [Node]

        public init(title: TimelineItem.Title, link: Link, children: [Node] = []) {
            self.title = title
            self.link = link
            self.children = children
        }
    }

    /// Top-level items.
    public let items: [TimelineItem]

    private let resolver: any TimelinePositionResolver

    /// All the items, indexed by their ID.
    private let allItems: [TimelineItem]

    /// ID of the parent of each item.
    private let parentIDs: [Int?]

    /// Depth of each item, starting at 1 for the top level.
    private let depths: [Int]

    /// IDs of the items with a range, in pre-order, which is also the order
    /// of their starts.
    private let rangedIDs: [Int]

    public init(nodes: [Node], resolver: any TimelinePositionResolver) {
        // Flattens the nodes in pre-order.
        var flatNodes: [Node] = []
        var parentIDs: [Int?] = []
        var depths: [Int] = []
        var childIDs: [[Int]] = []
        // ID following the subtree of each node.
        var subtreeEnds: [Int] = []

        @discardableResult
        func flatten(_ node: Node, parentID: Int?, depth: Int) -> Int {
            let nodeID = flatNodes.count
            flatNodes.append(node)
            parentIDs.append(parentID)
            depths.append(depth)
            childIDs.append([])
            subtreeEnds.append(nodeID)
            for child in node.children {
                childIDs[nodeID].append(flatten(child, parentID: nodeID, depth: depth + 1))
            }
            subtreeEnds[nodeID] = flatNodes.count
            return nodeID
        }

        let topLevelIDs = nodes.map { flatten($0, parentID: nil, depth: 1) }

        // Places the nodes in pre-order. A node starting before the last
        // placed one is left without a range.
        var starts: [TimelinePosition?] = []
        var rangedIDs: [Int] = []
        for (nodeID, node) in flatNodes.enumerated() {
            var start = resolver.position(of: node.link)
            if let lastID = rangedIDs.last, let lastStart = starts[lastID], let position = start, position.isBefore(lastStart) {
                start = nil
            }
            starts.append(start)
            if start != nil {
                rangedIDs.append(nodeID)
            }
        }

        // Start of the first ranged item from each ID.
        var nextStarts = [TimelinePosition?](repeating: nil, count: flatNodes.count + 1)
        for nodeID in flatNodes.indices.reversed() {
            nextStarts[nodeID] = starts[nodeID] ?? nextStarts[nodeID + 1]
        }

        // Builds the items from the leaves, as children follow their parent
        // in pre-order.
        var allItems = [TimelineItem?](repeating: nil, count: flatNodes.count)
        for (nodeID, node) in flatNodes.enumerated().reversed() {
            allItems[nodeID] = TimelineItem(
                id: nodeID,
                title: node.title,
                link: node.link,
                start: starts[nodeID],
                end: starts[nodeID].flatMap { start in
                    // An item can start past the known end of the
                    // publication.
                    nextStarts[subtreeEnds[nodeID]] ?? resolver.end.map { $0.isBefore(start) ? start : $0 }
                },
                children: childIDs[nodeID].map { allItems[$0]! }
            )
        }

        let builtItems = allItems.map { $0! }
        self.allItems = builtItems
        items = topLevelIDs.map { builtItems[$0] }
        self.resolver = resolver
        self.parentIDs = parentIDs
        self.depths = depths
        self.rangedIDs = rangedIDs
    }

    /// Returns the deepest item containing `locator`, or `nil` when it is
    /// outside the reading order or before the first item.
    ///
    /// - Parameter maxDepth: Returns an ancestor of the deepest item, no
    ///   deeper than this depth. The top level is 1.
    public func locate(_ locator: Locator, maxDepth: Int? = nil) -> TimelineItem? {
        guard
            maxDepth.map({ $0 >= 1 }) ?? true,
            let position = resolver.position(of: locator)
        else {
            return nil
        }

        // Index of the first ranged item starting after the position.
        var low = 0
        var high = rangedIDs.count
        while low < high {
            let middle = (low + high) / 2
            if !position.isBefore(allItems[rangedIDs[middle]].start!) {
                low = middle + 1
            } else {
                high = middle
            }
        }
        guard low > 0 else {
            return nil
        }

        return labelID(of: rangedIDs[low - 1], maxDepth: maxDepth).map { allItems[$0] }
    }

    /// Returns the first item with a range in pre-order, or `nil` when no
    /// placed item is within `maxDepth`.
    ///
    /// - Parameter maxDepth: Skips the items deeper than this depth. The top
    ///   level is 1.
    public func first(maxDepth: Int? = nil) -> TimelineItem? {
        rangedIDs
            .first { isWithin($0, maxDepth: maxDepth) }
            .map { allItems[$0] }
    }

    /// Returns the item before `item` in pre-order, skipping the items
    /// without a range or sharing its start.
    ///
    /// - Parameter maxDepth: Skips the items deeper than this depth. The top
    ///   level is 1.
    public func previous(before item: TimelineItem, maxDepth: Int? = nil) -> TimelineItem? {
        guard contains(item) else {
            return nil
        }
        return rangedIDs.last { candidateID in
            candidateID < item.id
                && isWithin(candidateID, maxDepth: maxDepth)
                && item.start.map { allItems[candidateID].start!.isBefore($0) } ?? true
        }
        .map { allItems[$0] }
    }

    /// Returns the item after `item` in pre-order, skipping the items without
    /// a range or sharing its start.
    ///
    /// - Parameter maxDepth: Skips the items deeper than this depth. The top
    ///   level is 1.
    public func next(after item: TimelineItem, maxDepth: Int? = nil) -> TimelineItem? {
        guard contains(item) else {
            return nil
        }
        return rangedIDs.first { candidateID in
            candidateID > item.id
                && isWithin(candidateID, maxDepth: maxDepth)
                && item.start.map { $0.isBefore(allItems[candidateID].start!) } ?? true
        }
        .map { allItems[$0] }
    }

    /// Returns the ancestors of `item`, from the top level down to its
    /// parent. Empty for a top-level item.
    public func ancestors(of item: TimelineItem) -> [TimelineItem] {
        guard contains(item) else {
            return []
        }
        var ancestors: [TimelineItem] = []
        var parentID = parentIDs[item.id]
        while let id = parentID {
            ancestors.insert(allItems[id], at: 0)
            parentID = parentIDs[id]
        }
        return ancestors
    }

    /// Returns consecutive segments covering the timeline, each labelled with
    /// the deepest item playing in it.
    ///
    /// The item of a segment is the one returned by ``locate(_:maxDepth:)``
    /// in it.
    ///
    /// - Parameter maxDepth: Labels the segments with items no deeper than
    ///   this depth. The top level is 1.
    public func segments(maxDepth: Int? = nil) -> [TimelineSegment] {
        var segments: [TimelineSegment] = []

        // Each ranged item starts an interval up to the next one, labelled
        // like `locate` would in it.
        for (index, rangedID) in rangedIDs.enumerated() {
            guard let labelID = labelID(of: rangedID, maxDepth: maxDepth) else {
                continue
            }
            let item = allItems[labelID]
            let start = allItems[rangedID].start!
            var end = item.end
            if index + 1 < rangedIDs.count, let next = allItems[rangedIDs[index + 1]].start, end.map({ next.isBefore($0) }) ?? true {
                end = next
            }
            guard end.map({ start.isBefore($0) }) ?? true else {
                continue
            }

            // The items of a subtree are consecutive in pre-order, so the
            // intervals of a label are adjacent.
            if let last = segments.last, last.item.id == labelID {
                segments[segments.count - 1] = TimelineSegment(item: item, start: last.start, end: end)
            } else {
                segments.append(TimelineSegment(item: item, start: start, end: end))
            }
        }

        return segments
    }

    /// Returns the segments of ``segments(maxDepth:)`` in the reading order
    /// resource at `href`, with positions clipped to the resource.
    ///
    /// Empty when `href` is not in the reading order.
    public func segments(in href: any URLConvertible, maxDepth: Int? = nil) -> [TimelineSegment] {
        guard let (resourceStart, resourceEnd) = resolver.bounds(ofResource: href) else {
            return []
        }
        let index = resourceStart.readingOrderIndex

        return segments(maxDepth: maxDepth).compactMap { segment in
            guard
                segment.start.readingOrderIndex <= index,
                segment.end.map({ resourceStart.isBefore($0) }) ?? true
            else {
                return nil
            }

            let start = segment.start.isBefore(resourceStart) ? resourceStart : segment.start
            // A segment can end past the known end of its resource.
            let end = segment.end
                .flatMap { $0.readingOrderIndex == index ? $0 : nil }
                .map { end in resourceEnd.map { $0.isBefore(end) ? $0 : end } ?? end }
                ?? resourceEnd
            guard end.map({ start.isBefore($0) }) ?? true else {
                return nil
            }
            return TimelineSegment(item: segment.item, start: start, end: end)
        }
    }

    /// Returns whether `item` belongs to this timeline.
    private func contains(_ item: TimelineItem) -> Bool {
        allItems.indices.contains(item.id) && allItems[item.id] == item
    }

    /// Returns the ID of the item labelling the positions from the start of
    /// the ranged item `itemID`: itself, or its closest ranged ancestor
    /// within `maxDepth`.
    private func labelID(of itemID: Int, maxDepth: Int?) -> Int? {
        var labelID: Int? = itemID
        while let currentID = labelID, !isRanged(currentID) || !isWithin(currentID, maxDepth: maxDepth) {
            labelID = parentIDs[currentID]
        }
        return labelID
    }

    private func isRanged(_ itemID: Int) -> Bool {
        allItems[itemID].start != nil
    }

    private func isWithin(_ itemID: Int, maxDepth: Int?) -> Bool {
        maxDepth.map { depths[itemID] <= $0 } ?? true
    }
}
