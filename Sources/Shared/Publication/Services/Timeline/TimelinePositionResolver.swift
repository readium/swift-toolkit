//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Resolves locations of a publication into positions on its ``Timeline``,
/// following the rules of its format.
///
/// The same resolution is used to build a timeline and to query it.
@_spi(ExperimentalTimeline)
public protocol TimelinePositionResolver: Sendable {
    /// Reading order laid out on the timeline.
    var readingOrder: [Link] { get }

    /// Position of the given link, from its HREF and fragment, or `nil` when
    /// it is outside the reading order.
    func position(of link: Link) -> TimelinePosition?

    /// Position of the given locator, or `nil` when it is outside the reading
    /// order.
    func position(of locator: Locator) -> TimelinePosition?

    /// Start and end of the reading order resource at `index`, which must be
    /// in `readingOrder.indices`. The end is `nil` when it is unknown.
    ///
    /// The end of the last resource is the end of the publication, at a
    /// `totalProgression` of 1.
    func bounds(ofResourceAt index: Int) -> (start: TimelinePosition, end: TimelinePosition?)

    /// Length between `start` and `end`, negative when `end` is before
    /// `start`, or `nil` when the length of a resource between them is
    /// unknown.
    func length(from start: TimelinePosition, to end: TimelinePosition) -> TimelineLength?
}

@_spi(ExperimentalTimeline)
public extension TimelinePositionResolver {
    /// End of the publication, or `nil` when it is unknown.
    var end: TimelinePosition? {
        readingOrder.isEmpty ? nil : bounds(ofResourceAt: readingOrder.count - 1).end
    }
}
