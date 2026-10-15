//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A range of a ``Timeline`` labelled with the ``TimelineItem`` playing in it.
@_spi(ExperimentalTimeline)
public struct TimelineSegment: Hashable, Sendable {
    public let item: TimelineItem

    public let start: TimelinePosition

    /// Exclusive end of the segment, or `nil` when it ends at the end of a
    /// resource whose duration is unknown.
    public let end: TimelinePosition?

    package init(item: TimelineItem, start: TimelinePosition, end: TimelinePosition?) {
        self.item = item
        self.start = start
        self.end = end
    }
}
