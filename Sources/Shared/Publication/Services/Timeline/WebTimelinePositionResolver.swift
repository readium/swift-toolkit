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
package struct WebTimelinePositionResolver: TimelinePositionResolver {
    private let readingOrder: [Link]

    /// First entry pointing to each reading order resource, by index.
    ///
    /// Entries are matched by value, so a duplicate of a first entry is placed
    /// too, at the same start.
    private let firstEntries: [Int: Link]

    /// - Parameter nodes: Nodes of the timeline, whose first entry pointing to
    ///   each resource is placed.
    package init(readingOrder: [Link], nodes: [Timeline.Node]) {
        self.readingOrder = readingOrder

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

    package func position(of locator: Locator) -> TimelinePosition? {
        guard let index = readingOrder.firstIndexWithHREF(locator.href) else {
            return nil
        }
        return TimelinePosition(
            readingOrderIndex: index,
            offset: .scroll(locator.locations.progression ?? 0)
        )
    }

    package func bounds(ofResource href: any URLConvertible) -> (start: TimelinePosition, end: TimelinePosition?)? {
        readingOrder.firstIndexWithHREF(href).map { (start(ofResourceAt: $0), end(ofResourceAt: $0)) }
    }

    private func start(ofResourceAt index: Int) -> TimelinePosition {
        TimelinePosition(readingOrderIndex: index, offset: .scroll(0))
    }

    private func end(ofResourceAt index: Int) -> TimelinePosition {
        TimelinePosition(readingOrderIndex: index, offset: .scroll(1))
    }
}
