//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Resolves the locations of a publication of bitmap images, such as a
/// comic, into positions on its timeline, with one page per image of its
/// reading order.
///
/// A link or a locator is at the start of its image, whose offset is 0. The
/// end of an image is at an offset of 1.
package struct ImageTimelinePositionResolver: TimelinePositionResolver {
    private let layout: TimelineLayout<Int>

    package init(readingOrder: [Link]) {
        layout = TimelineLayout(
            readingOrder: readingOrder,
            lengths: Array(repeating: 1, count: readingOrder.count),
            coordinate: { .page($0 + 1) }
        )
    }

    package var readingOrder: [Link] {
        layout.readingOrder
    }

    package func position(of link: Link) -> TimelinePosition? {
        layout.index(of: link.url()).map { layout.position(at: $0, offset: 0) }
    }

    package func position(of locator: Locator) -> TimelinePosition? {
        layout.index(of: locator.href).map { layout.position(at: $0, offset: 0) }
    }

    package func bounds(ofResourceAt index: Int) -> (start: TimelinePosition, end: TimelinePosition?) {
        layout.bounds(ofResourceAt: index)
    }

    package func length(from start: TimelinePosition, to end: TimelinePosition) -> TimelineLength? {
        layout.length(from: start, to: end).map { .pages($0) }
    }
}
