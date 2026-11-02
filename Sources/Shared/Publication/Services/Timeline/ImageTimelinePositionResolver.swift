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

    package var end: TimelinePosition? {
        layout.end
    }

    package func position(of link: Link) -> TimelinePosition? {
        layout.bounds(ofResource: link.url())?.start
    }

    package func position(of locator: Locator) -> TimelinePosition? {
        layout.bounds(ofResource: locator.href)?.start
    }

    package func bounds(ofResource href: any URLConvertible) -> (start: TimelinePosition, end: TimelinePosition?)? {
        layout.bounds(ofResource: href)
    }

    package func length(from start: TimelinePosition, to end: TimelinePosition?) -> TimelineLength? {
        end
            .flatMap { layout.length(from: start, to: $0) }
            .map { .pages($0) }
    }
}
