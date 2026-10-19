//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Resolves the locations of an audio publication into positions on its
/// timeline, from the durations of its reading order.
///
/// A missing or non-positive duration is unknown.
package struct AudioTimelinePositionResolver: TimelinePositionResolver {
    private let layout: TimelineLayout<TimeInterval>

    package init(readingOrder: [Link]) {
        layout = TimelineLayout(
            readingOrder: readingOrder,
            lengths: readingOrder.map(\.duration),
            offset: TimelineOffset.seconds
        )
    }

    package var end: TimelinePosition? {
        layout.end
    }

    package func position(of link: Link) -> TimelinePosition? {
        let url = link.url()
        guard let index = layout.index(of: url) else {
            return nil
        }
        return layout.position(at: index, offset: url.fragment?.temporalSelector?.start ?? 0)
    }

    package func position(of locator: Locator) -> TimelinePosition? {
        guard let index = layout.index(of: locator.href) else {
            return nil
        }

        let offset = locator.locations.temporal?.start
            ?? locator.locations.progression.flatMap { progression in
                layout.length(ofResourceAt: index).map { progression * $0 }
            }
            ?? 0

        return layout.position(at: index, offset: offset)
    }

    package func bounds(ofResource href: any URLConvertible) -> (start: TimelinePosition, end: TimelinePosition?)? {
        layout.bounds(ofResource: href)
    }
}
