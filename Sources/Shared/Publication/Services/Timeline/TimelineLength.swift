//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Length on a ``Timeline``, such as of a ``TimelineTOCEntry`` or between two
/// positions, in the natural unit of its publication.
///
/// Between two positions, it is negative when the second one is before the
/// first one.
@_spi(ExperimentalTimeline)
public enum TimelineLength: Hashable, Sendable {
    /// Duration, in seconds.
    case duration(TimeInterval)

    /// Number of pages.
    case pages(Int)

    /// Number of positions in the positions list of the publication.
    case positions(Int)

    /// Duration in seconds, or `nil` when the length is counted in pages or
    /// positions.
    public var seconds: TimeInterval? {
        switch self {
        case let .duration(seconds): seconds
        case .pages, .positions: nil
        }
    }

    /// Number of pages or positions, or `nil` when the length is a duration.
    public var count: Int? {
        switch self {
        case let .pages(count), let .positions(count): count
        case .duration: nil
        }
    }
}
