//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A length of a resource on a timeline, such as a duration or a page count.
package protocol TimelineLength: AdditiveArithmetic, Comparable, Sendable {
    var doubleValue: Double { get }
}

extension Int: TimelineLength {
    package var doubleValue: Double { Double(self) }
}

extension Double: TimelineLength {
    package var doubleValue: Double { self }
}

/// Lays out the resources of a reading order one after the other on a
/// timeline, from their lengths.
///
/// A missing or non-positive length is unknown.
package struct TimelineLayout<Length: TimelineLength>: Sendable {
    private let readingOrder: [Link]

    /// Length of each reading order resource.
    private let lengths: [Length?]

    /// Offset of each reading order resource from the start of the
    /// publication, `nil` when a preceding length is unknown.
    private let startOffsets: [Length?]

    /// Length of the publication, `nil` when a length is unknown.
    private let totalLength: Length?

    /// Turns a length into an offset of the timeline.
    private let makeOffset: @Sendable (Length) -> TimelineOffset

    /// - Parameters:
    ///   - lengths: Length of each reading order resource, by index.
    ///   - offset: Turns a length into an offset of the timeline, such as
    ///     `TimelineOffset.seconds`.
    package init(
        readingOrder: [Link],
        lengths: [Length?],
        offset: @escaping @Sendable (Length) -> TimelineOffset
    ) {
        self.readingOrder = readingOrder
        makeOffset = offset
        self.lengths = readingOrder.indices.map { index in
            lengths.getOrNil(index).flatMap { $0 }.flatMap { $0 > .zero ? $0 : nil }
        }

        var startOffsets: [Length?] = []
        var total: Length? = .zero
        for length in self.lengths {
            startOffsets.append(total)
            total = total.flatMap { total in length.map { total + $0 } }
        }
        self.startOffsets = startOffsets
        totalLength = total
    }

    /// Length of the resource at `index`, `nil` when it is unknown.
    package func length(ofResourceAt index: Int) -> Length? {
        lengths[index]
    }

    /// Offset of the resource at `index` from the start of the publication,
    /// `nil` when a preceding length is unknown.
    package func startOffset(ofResourceAt index: Int) -> Length? {
        startOffsets[index]
    }

    /// Index of the reading order resource at `href`, ignoring its fragment.
    package func index(of href: any URLConvertible) -> Int? {
        readingOrder.firstIndexWithHREF(href)
    }

    /// End of the publication, or `nil` when the reading order is empty or
    /// the length of its last resource is unknown.
    package var end: TimelinePosition? {
        guard !readingOrder.isEmpty else {
            return nil
        }
        return end(ofResourceAt: readingOrder.count - 1)
    }

    /// Start and end of the reading order resource at `href`, ignoring its
    /// fragment, or `nil` when it is not in the reading order. The end is
    /// `nil` when the length of the resource is unknown.
    package func bounds(ofResource href: any URLConvertible) -> (start: TimelinePosition, end: TimelinePosition?)? {
        guard let index = index(of: href) else {
            return nil
        }
        return (position(at: index, offset: .zero), end(ofResourceAt: index))
    }

    /// Position at `offset` in the resource at `index`.
    package func position(at index: Int, offset: Length) -> TimelinePosition {
        let totalOffset = startOffsets[index].map { $0 + offset }

        return TimelinePosition(
            readingOrderIndex: index,
            offset: makeOffset(offset),
            totalOffset: totalOffset.map(makeOffset),
            progression: lengths[index].map { offset.doubleValue / $0.doubleValue },
            totalProgression: totalOffset.flatMap { totalOffset in
                totalLength.map { totalOffset.doubleValue / $0.doubleValue }
            }
        )
    }

    /// End of the reading order resource at `index`, or `nil` when its
    /// length is unknown.
    private func end(ofResourceAt index: Int) -> TimelinePosition? {
        guard let length = lengths[index] else {
            return nil
        }
        let end = position(at: index, offset: length)

        // The end of the publication is at 100%, even when the length of a
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
}
