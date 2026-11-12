//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A part of a ``Timeline`` matching a single ``TimelineTOCEntry``.
///
/// It ends where another entry takes over, such as the first child of its
/// entry.
///
/// Outside any entry, such as before the first one or without a table of
/// contents, a segment covers a reading order resource instead, or the part
/// of it outside any entry.
@_spi(ExperimentalTimeline)
public struct TimelineSegment: Hashable, Sendable {
    /// Entry of the table of contents located in the segment, or `nil` where
    /// there are none, such as before the first one or without a table of
    /// contents.
    public let tocEntry: TimelineTOCEntry?

    /// Link to the start of the segment, to go there with
    /// `Navigator.go(to:)`.
    public let link: Link

    /// Start of the segment in the timeline.
    public let start: TimelinePosition

    /// Exclusive end of the segment, or `nil` when it ends at the end of a
    /// resource whose length is unknown.
    public let end: TimelinePosition?

    package init(tocEntry: TimelineTOCEntry?, link: Link, start: TimelinePosition, end: TimelinePosition?) {
        self.tocEntry = tocEntry
        self.link = link
        self.start = start
        self.end = end
    }
}
