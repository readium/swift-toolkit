//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A range of a ``Timeline`` labelled with the ``TimelineItem`` containing it,
/// if any.
@_spi(ExperimentalTimeline)
public struct TimelineSegment: Hashable, Sendable {
    /// Item located in the segment, or `nil` where there are none, such as
    /// before the first one.
    public let item: TimelineItem?

    /// Link to the start of the segment, to go there with
    /// `Navigator.go(to:)`.
    public let link: Link

    public let start: TimelinePosition

    /// Exclusive end of the segment, or `nil` when it ends at the end of a
    /// resource whose length is unknown.
    public let end: TimelinePosition?

    package init(item: TimelineItem?, link: Link, start: TimelinePosition, end: TimelinePosition?) {
        self.item = item
        self.link = link
        self.start = start
        self.end = end
    }
}
