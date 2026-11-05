//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Resolves the locations of a web publication, such as an EPUB, into
/// positions on its timeline.
///
/// The first table of contents entry pointing to each reading order resource
/// is placed at the start of the resource. A locator resolves to its resource
/// and progression only, so a fixed-layout resource is like a reflowable one
/// that is never scrolled. Each resource ends at a progression of 1.
///
/// The offset of a position is its progression in its resource, and its
/// coordinate a `.position` in the positions list of the publication, or a
/// `.page` when the positions are pages. The coordinates, the lengths in
/// `.positions` or `.pages` and the progressions in the publication are
/// computed from the number of positions of each resource. A missing or
/// non-positive count is unknown.
package struct WebTimelinePositionResolver: TimelinePositionResolver {
    package let readingOrder: [Link]

    /// Lays out the positions of the reading order resources.
    private let layout: TimelineLayout<Int>

    /// Whether each position is a page.
    private let positionsArePages: Bool

    /// Makes the coordinate of a 1-based position in the publication.
    private let makeCoordinate: @Sendable (Int) -> TimelineCoordinate

    /// First entry pointing to each reading order resource, by index.
    ///
    /// Entries are matched by value, so a duplicate of a first entry is placed
    /// too, at the same start.
    private let firstEntries: [Int: Link]

    /// - Parameters:
    ///   - positionCounts: Number of positions of each reading order resource,
    ///     by index.
    ///   - positionsArePages: Whether each position is a page, as in a
    ///     fixed-layout publication.
    ///   - nodes: Nodes of the timeline, whose first entry pointing to each
    ///     resource is placed.
    package init(readingOrder: [Link], positionCounts: [Int?], positionsArePages: Bool = false, nodes: [Timeline.Node]) {
        self.readingOrder = readingOrder
        self.positionsArePages = positionsArePages
        let makeCoordinate: @Sendable (Int) -> TimelineCoordinate = positionsArePages
            ? TimelineCoordinate.page
            : TimelineCoordinate.position
        self.makeCoordinate = makeCoordinate
        layout = TimelineLayout(
            readingOrder: readingOrder,
            lengths: positionCounts,
            coordinate: { makeCoordinate($0 + 1) }
        )

        var firstEntries: [Int: Link] = [:]
        func record(_ nodes: [Timeline.Node]) {
            for node in nodes {
                if let index = readingOrder.firstIndexWithHREF(node.link.url()), firstEntries[index] == nil {
                    firstEntries[index] = node.link
                }
                record(node.children)
            }
        }
        record(nodes)
        self.firstEntries = firstEntries
    }

    package var end: TimelinePosition? {
        guard !readingOrder.isEmpty else {
            return nil
        }
        return end(ofResourceAt: readingOrder.count - 1)
    }

    package func position(of link: Link) -> TimelinePosition? {
        guard
            let index = readingOrder.firstIndexWithHREF(link.url()),
            firstEntries[index] == link
        else {
            return nil
        }
        return start(ofResourceAt: index)
    }

    /// The progression is clamped between 0 and 1. The coordinate is the
    /// position of the locator in the publication when it is in its
    /// resource, else the position at its progression.
    package func position(of locator: Locator) -> TimelinePosition? {
        guard let index = readingOrder.firstIndexWithHREF(locator.href) else {
            return nil
        }
        let progression = min(max(0, locator.locations.progression ?? 0), 1)
        return position(at: index, progression: progression) { positionsBefore in
            let count = layout.length(ofResourceAt: index)
            if
                let position = locator.locations.position,
                position > positionsBefore,
                count.map({ position <= positionsBefore + $0 }) ?? true
            {
                return position
            }
            return layout.offset(atProgression: progression, inResourceAt: index).map { positionsBefore + $0 + 1 }
        }
    }

    package func bounds(ofResource href: any URLConvertible) -> (start: TimelinePosition, end: TimelinePosition?)? {
        readingOrder.firstIndexWithHREF(href).map { (start(ofResourceAt: $0), end(ofResourceAt: $0)) }
    }

    package func length(from start: TimelinePosition, to end: TimelinePosition) -> TimelineLength? {
        guard
            let start = countingPositions(start),
            let end = countingPositions(end)
        else {
            return nil
        }
        return layout.length(from: start, to: end).map { positionsArePages ? .pages($0) : .positions($0) }
    }

    private func start(ofResourceAt index: Int) -> TimelinePosition {
        position(at: index, progression: 0) { $0 + 1 }
    }

    /// The coordinate of the end is one past the last position of the
    /// resource.
    private func end(ofResourceAt index: Int) -> TimelinePosition {
        position(at: index, progression: 1) { positionsBefore in
            layout.length(ofResourceAt: index).map { positionsBefore + $0 + 1 }
        }
    }

    /// Position at `progression` in the resource at `index`.
    ///
    /// - Parameter coordinate: Returns the 1-based position in the
    ///   publication from the number of positions before the resource, or
    ///   `nil` when it is unknown.
    private func position(
        at index: Int,
        progression: Double,
        coordinate: (_ positionsBefore: Int) -> Int?
    ) -> TimelinePosition {
        TimelinePosition(
            readingOrderIndex: index,
            offset: progression,
            coordinate: layout.startOffset(ofResourceAt: index).flatMap(coordinate).map(makeCoordinate),
            progression: progression,
            totalProgression: layout.totalProgression(at: progression, inResourceAt: index)
        )
    }

    /// Returns `position` with an offset counted in positions instead of a
    /// progression, or `nil` when the number of positions of its resource is
    /// unknown.
    ///
    /// The offset is read from the coordinate when it is known, so that a
    /// length agrees with the coordinates, else from the progression. The
    /// start of a resource does not depend on its number of positions.
    private func countingPositions(_ position: TimelinePosition) -> TimelinePosition? {
        let index = position.readingOrderIndex
        let coordinate: Int? = switch position.coordinate {
        case let .position(coordinate)?, let .page(coordinate)?: coordinate
        case .time?, nil: nil
        }
        if let coordinate, let positionsBefore = layout.startOffset(ofResourceAt: index) {
            return TimelinePosition(readingOrderIndex: index, offset: Double(coordinate - positionsBefore - 1))
        }
        guard position.offset > 0 else {
            return TimelinePosition(readingOrderIndex: index, offset: 0)
        }
        guard let count = layout.length(ofResourceAt: index) else {
            return nil
        }
        return TimelinePosition(readingOrderIndex: index, offset: (position.offset * Double(count)).rounded(.down))
    }
}
