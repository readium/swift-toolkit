//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A numeric type a timeline is measured in, such as `Double` seconds or
/// `Int` pages.
package protocol TimelineScalar: AdditiveArithmetic, Comparable, Sendable {
    /// Creates a scalar from the offset of a position, or `nil` when it
    /// cannot be represented exactly.
    init?(exactly source: Double)

    var doubleValue: Double { get }
}

extension Int: TimelineScalar {
    package var doubleValue: Double {
        Double(self)
    }
}

extension Double: TimelineScalar {
    package var doubleValue: Double {
        self
    }
}

/// Lays out the resources of a reading order one after the other on a
/// timeline, from their lengths.
///
/// A missing or non-positive length is unknown.
package struct TimelineLayout<Scalar: TimelineScalar>: Sendable {
    private let readingOrder: [Link]

    /// Length of each reading order resource.
    private let lengths: [Scalar?]

    /// Offset of each reading order resource from the start of the
    /// publication, `nil` when a preceding length is unknown.
    private let startOffsets: [Scalar?]

    /// Length of the publication, `nil` when a length is unknown.
    package let totalLength: Scalar?

    /// Turns an offset from the start of the publication into a coordinate.
    private let makeCoordinate: @Sendable (Scalar) -> TimelineCoordinate

    /// - Parameters:
    ///   - lengths: Length of each reading order resource, by index.
    ///   - coordinate: Turns an offset from the start of the publication
    ///     into a coordinate, such as `TimelineCoordinate.time`.
    package init(
        readingOrder: [Link],
        lengths: [Scalar?],
        coordinate: @escaping @Sendable (Scalar) -> TimelineCoordinate
    ) {
        self.readingOrder = readingOrder
        makeCoordinate = coordinate
        self.lengths = readingOrder.indices.map { index in
            lengths.getOrNil(index).flatMap { $0 }.flatMap { $0 > .zero ? $0 : nil }
        }

        var startOffsets: [Scalar?] = []
        var total: Scalar? = .zero
        for length in self.lengths {
            startOffsets.append(total)
            total = total.flatMap { total in length.map { total + $0 } }
        }
        self.startOffsets = startOffsets
        totalLength = total
    }

    /// Length of the resource at `index`, `nil` when it is unknown or outside
    /// the reading order.
    package func length(ofResourceAt index: Int) -> Scalar? {
        lengths.getOrNil(index) ?? nil
    }

    /// Offset of the resource at `index` from the start of the publication,
    /// `nil` when a preceding length is unknown.
    package func startOffset(ofResourceAt index: Int) -> Scalar? {
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
    package func position(at index: Int, offset: Scalar) -> TimelinePosition {
        let totalOffset = startOffsets[index].map { $0 + offset }

        return TimelinePosition(
            readingOrderIndex: index,
            offset: offset.doubleValue,
            coordinate: totalOffset.map(makeCoordinate),
            progression: lengths[index].map { offset.doubleValue / $0.doubleValue },
            totalProgression: totalOffset.flatMap { totalOffset in
                totalLength.map { totalOffset.doubleValue / $0.doubleValue }
            }
        )
    }

    /// Length between `start` and `end`, or `nil` when the length of a
    /// resource between them is unknown, `end` is before `start`, or one of
    /// them is outside the reading order.
    ///
    /// A `start` past the known length of its resource, when `end` is in a
    /// later resource, shows that this length is wrong: it is unknown too.
    ///
    /// Unlike the coordinates, it does not depend on the lengths of the
    /// resources before `start`.
    package func length(from start: TimelinePosition, to end: TimelinePosition) -> Scalar? {
        guard
            lengths.indices.contains(start.readingOrderIndex),
            lengths.indices.contains(end.readingOrderIndex),
            !end.isBefore(start),
            let startOffset = Scalar(exactly: start.offset),
            var length = Scalar(exactly: end.offset)
        else {
            return nil
        }
        length -= startOffset
        for index in start.readingOrderIndex ..< end.readingOrderIndex {
            guard
                let resourceLength = lengths[index],
                index > start.readingOrderIndex || startOffset <= resourceLength
            else {
                return nil
            }
            length += resourceLength
        }
        return length
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
                coordinate: end.coordinate,
                progression: end.progression,
                totalProgression: 1
            )
        }
        return end
    }
}

extension TimelineLayout where Scalar == Int {
    /// Index of the page or position at `progression` in the resource at
    /// `index`, starting at 0, or `nil` when its length is unknown.
    ///
    /// The progression is clamped between 0 and 1. A progression of 1 is the
    /// last page or position of the resource.
    package func unit(at progression: Double, inResourceAt index: Int) -> Int? {
        guard let length = lengths[index] else {
            return nil
        }
        let unit = Int((min(max(0, progression), 1) * Double(length)).rounded(.down))
        return min(unit, length - 1)
    }
}
