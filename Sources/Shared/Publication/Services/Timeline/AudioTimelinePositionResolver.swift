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
    private let readingOrder: [Link]

    /// Duration of each reading order resource.
    private let durations: [TimeInterval?]

    /// Offset of each reading order resource from the start of the
    /// publication, `nil` when a preceding duration is unknown.
    private let startOffsets: [TimeInterval?]

    /// Duration of the publication, `nil` when a duration is unknown.
    private let totalDuration: TimeInterval?

    package init(readingOrder: [Link]) {
        self.readingOrder = readingOrder
        durations = readingOrder.map { link in
            link.duration.flatMap { $0 > 0 ? $0 : nil }
        }

        var startOffsets: [TimeInterval?] = []
        var offset: TimeInterval? = 0
        for duration in durations {
            startOffsets.append(offset)
            offset = offset.flatMap { offset in duration.map { offset + $0 } }
        }
        self.startOffsets = startOffsets
        totalDuration = offset
    }

    package var end: TimelinePosition? {
        guard !readingOrder.isEmpty else {
            return nil
        }
        return end(ofResourceAt: readingOrder.count - 1)
    }

    package func position(of link: Link) -> TimelinePosition? {
        let url = link.url()
        guard let index = readingOrder.firstIndexWithHREF(url) else {
            return nil
        }
        return position(at: index, offset: url.fragment?.temporalSelector?.start ?? 0)
    }

    package func position(of locator: Locator) -> TimelinePosition? {
        guard let index = readingOrder.firstIndexWithHREF(locator.href) else {
            return nil
        }

        let offset = locator.locations.temporal?.start
            ?? locator.locations.progression.flatMap { progression in
                durations[index].map { progression * $0 }
            }
            ?? 0

        return position(at: index, offset: offset)
    }

    package func bounds(ofResource href: any URLConvertible) -> (start: TimelinePosition, end: TimelinePosition?)? {
        guard let index = readingOrder.firstIndexWithHREF(href) else {
            return nil
        }
        return (position(at: index, offset: 0), end(ofResourceAt: index))
    }

    /// End of the reading order resource at `index`, or `nil` when its
    /// duration is unknown.
    private func end(ofResourceAt index: Int) -> TimelinePosition? {
        guard let duration = durations[index] else {
            return nil
        }
        let end = position(at: index, offset: duration)

        // The end of the publication is at 100%, even when the duration of a
        // preceding resource is unknown.
        guard index < readingOrder.count - 1 else {
            return TimelinePosition(
                readingOrderIndex: index,
                offset: end.offset,
                totalOffset: end.totalOffset,
                progression: end.progression,
                totalProgression: 1
            )
        }
        return end
    }

    private func position(at index: Int, offset: TimeInterval) -> TimelinePosition {
        let duration = durations[index]
        let totalOffset = startOffsets[index].map { $0 + offset }

        return TimelinePosition(
            readingOrderIndex: index,
            offset: .seconds(offset),
            totalOffset: totalOffset.map { .seconds($0) },
            progression: duration.map { offset / $0 },
            totalProgression: totalOffset.flatMap { totalOffset in
                totalDuration.map { totalOffset / $0 }
            }
        )
    }
}
