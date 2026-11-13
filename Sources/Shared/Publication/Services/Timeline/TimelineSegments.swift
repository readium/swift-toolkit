//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// The segments of a ``Timeline``, following each other from the start of
/// the reading order to its end.
///
/// ``Timeline/segments(maxDepth:)`` builds a new collection at each call, for
/// a single `maxDepth`. Keep it to locate each new location.
@_spi(ExperimentalTimeline)
public struct TimelineSegments: RandomAccessCollection, Sendable {
    private let segments: [TimelineSegment]
    private let resolver: any TimelinePositionResolver

    package init(segments: [TimelineSegment], resolver: any TimelinePositionResolver) {
        self.segments = segments
        self.resolver = resolver
    }

    public var startIndex: Int {
        segments.startIndex
    }

    public var endIndex: Int {
        segments.endIndex
    }

    public subscript(index: Int) -> TimelineSegment {
        segments[index]
    }

    /// Returns the segment containing `locator`, or `nil` when it is outside
    /// the reading order.
    ///
    /// Unlike the entry, the segment ends where the next entry starts, such
    /// as the first child of a parent entry. Use it to measure what is left of
    /// the current chapter.
    ///
    /// Past the end of the last segment, such as past the known end of the
    /// publication, it is the last segment.
    public func segment(containing locator: Locator) -> TimelineSegment? {
        resolver.position(of: locator)
            .flatMap { index(containing: $0) }
            .map { segments[$0] }
    }

    /// Returns the segment before `segment`, such as the previous chapter, or
    /// `nil` when it is the first one.
    public func segment(before segment: TimelineSegment) -> TimelineSegment? {
        guard let index = index(containing: segment.start), index > startIndex else {
            return nil
        }
        return segments[index - 1]
    }

    /// Returns the segment after `segment`, such as the next chapter, or
    /// `nil` when it is the last one.
    public func segment(after segment: TimelineSegment) -> TimelineSegment? {
        guard let index = index(containing: segment.start), index + 1 < endIndex else {
            return nil
        }
        return segments[index + 1]
    }

    /// Returns the segments in the reading order resource at `href`, with
    /// positions clipped to the resource.
    ///
    /// Empty when `href` is not in the reading order.
    public func segments(in href: any URLConvertible) -> [TimelineSegment] {
        guard let index = resolver.readingOrder.firstIndexWithHREF(href) else {
            return []
        }
        let (resourceStart, resourceEnd) = resolver.bounds(ofResourceAt: index)

        // The segments follow each other, so the ones before the segment
        // containing the start of the resource end before it.
        let firstIndex = self.index(containing: resourceStart) ?? startIndex

        return segments[firstIndex...]
            .prefix { $0.start.readingOrderIndex <= index }
            .compactMap { segment in
                guard segment.end.map({ resourceStart.isBefore($0) }) ?? true else {
                    return nil
                }

                let isClipped = segment.start.isBefore(resourceStart)
                let start = isClipped ? resourceStart : segment.start
                // A segment can end past the known end of its resource.
                let end = segment.end
                    .flatMap { $0.readingOrderIndex == index ? $0 : nil }
                    .map { end in resourceEnd.map { $0.isBefore(end) ? $0 : end } ?? end }
                    ?? resourceEnd
                guard end.map({ start.isBefore($0) }) ?? true else {
                    return nil
                }
                let link = isClipped ? resolver.readingOrder[index] : segment.link
                return TimelineSegment(tocEntry: segment.tocEntry, link: link, start: start, end: end)
            }
    }

    /// Returns the index of the segment containing `position`, or the last
    /// one past its end.
    private func index(containing position: TimelinePosition) -> Int? {
        // Index of the first segment starting after the position.
        var low = 0
        var high = segments.count
        while low < high {
            let middle = (low + high) / 2
            if !position.isBefore(segments[middle].start) {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low > 0 ? low - 1 : nil
    }
}
