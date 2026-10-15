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
    /// End of the publication, or `nil` when it is unknown.
    var end: TimelinePosition? { get }

    /// Position of the given link, from its HREF and fragment, or `nil` when
    /// it is outside the reading order.
    func position(of link: Link) -> TimelinePosition?

    /// Position of the given locator, or `nil` when it is outside the reading
    /// order.
    func position(of locator: Locator) -> TimelinePosition?

    /// Start and end of the reading order resource at `href`, ignoring its
    /// fragment, or `nil` when it is not in the reading order. The end is
    /// `nil` when it is unknown.
    func bounds(ofResource href: any URLConvertible) -> (start: TimelinePosition, end: TimelinePosition?)?
}
