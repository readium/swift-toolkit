//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A part of a ``Timeline`` from the start of a ``TimelineTOCEntry`` to the
/// start of the next one.
///
/// Outside any entry, such as before the first one or without a table of
/// contents, a segment is a reading order resource instead, up to where the
/// first entry starts.
@_spi(ExperimentalTimeline)
public struct TimelineSegment: Hashable, Sendable {
    /// Entry of the table of contents located in the segment, or `nil` where
    /// there are none, such as before the first one.
    public let tocEntry: TimelineTOCEntry?

    /// Link to the start of the segment, to go there with
    /// `Navigator.go(to:)`.
    public let link: Link

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
