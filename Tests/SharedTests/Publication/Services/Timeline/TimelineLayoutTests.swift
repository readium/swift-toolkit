//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) @testable import ReadiumShared
import Testing

/// Reading order: `a`, `b` and `c`, of 10, 5 and 20 pages unless a test gives
/// other lengths.
enum TimelineLayoutTests {
    struct Lengths {
        @Test func nonPositiveAndMissingLengthsAreUnknown() {
            let layout = layout([0, -5])

            #expect([0, 1, 2].map { layout.length(ofResourceAt: $0) } == [nil, nil, nil])
        }

        @Test func startOffsetIsUnknownAfterAnUnknownLength() {
            let layout = layout([10, nil, 20])

            #expect([0, 1, 2].map { layout.startOffset(ofResourceAt: $0) } == [0, 10, nil])
        }
    }

    struct Index {
        @Test func indexIgnoresTheFragment() {
            let layout = layout()

            #expect(layout.index(of: AnyURL(string: "b#page=2")!) == 1)
            #expect(layout.index(of: AnyURL(string: "outside")!) == nil)
        }
    }

    struct Positions {
        /// Position at page 2 of `b` with the given lengths.
        struct PositionLengths: Sendable, CustomTestStringConvertible {
            let name: String
            let lengths: [Int?]
            let expected: TimelinePosition

            var testDescription: String {
                name
            }
        }

        @Test(arguments: [
            PositionLengths(
                name: "all the lengths are known",
                lengths: [10, 5, 20],
                expected: position(1, 2, totalOffset: 12, progression: 0.4, totalProgression: 12.0 / 35)
            ),
            PositionLengths(
                name: "the length of the resource is unknown",
                lengths: [10, nil, 20],
                expected: position(1, 2, totalOffset: 12, progression: nil, totalProgression: nil)
            ),
            PositionLengths(
                name: "a preceding length is unknown",
                lengths: [nil, 5, 20],
                expected: position(1, 2, totalOffset: nil, progression: 0.4, totalProgression: nil)
            ),
            PositionLengths(
                name: "a later length is unknown",
                lengths: [10, 5, nil],
                expected: position(1, 2, totalOffset: 12, progression: 0.4, totalProgression: nil)
            ),
        ])
        func positionDependsOnTheLengths(_ example: PositionLengths) {
            #expect(layout(example.lengths).position(at: 1, offset: 2) == example.expected)
        }
    }

    struct Bounds {
        @Test func resourceBounds() {
            let layout = layout([10, 5, nil])

            #expect(layout.bounds(ofResource: AnyURL(string: "a")!)?.start == position(0, 0, totalOffset: 0, progression: 0, totalProgression: nil))
            #expect(layout.bounds(ofResource: AnyURL(string: "b")!)?.end == position(1, 5, totalOffset: 15, progression: 1, totalProgression: nil))
            #expect(layout.bounds(ofResource: AnyURL(string: "c")!)?.end == nil)
            #expect(layout.bounds(ofResource: AnyURL(string: "outside")!) == nil)
        }

        struct PublicationEnd: Sendable, CustomTestStringConvertible {
            let lengths: [Int?]
            let expected: TimelinePosition?

            var testDescription: String {
                "\(lengths)"
            }
        }

        /// The end of the publication is at 100%, even when a preceding length
        /// is unknown.
        @Test(arguments: [
            PublicationEnd(lengths: [10, 5, 20], expected: position(2, 20, totalOffset: 35, progression: 1, totalProgression: 1)),
            PublicationEnd(lengths: [nil, 5, 20], expected: position(2, 20, totalOffset: nil, progression: 1, totalProgression: 1)),
            PublicationEnd(lengths: [10, 5, nil], expected: nil),
        ])
        func publicationEnd(_ example: PublicationEnd) {
            #expect(layout(example.lengths).end == example.expected)
        }

        @Test func emptyReadingOrderHasNoEnd() {
            #expect(TimelineLayout<Int>(readingOrder: [], lengths: [], offset: TimelineOffset.page).end == nil)
        }
    }
}

// MARK: - Helpers

private func layout(_ lengths: [Int?] = [10, 5, 20]) -> TimelineLayout<Int> {
    TimelineLayout(
        readingOrder: [Link(href: "a"), Link(href: "b"), Link(href: "c")],
        lengths: lengths,
        offset: TimelineOffset.page
    )
}

private func position(
    _ index: Int,
    _ page: Int,
    totalOffset: Int?,
    progression: Double?,
    totalProgression: Double?
) -> TimelinePosition {
    TimelinePosition(
        readingOrderIndex: index,
        offset: .page(page),
        totalOffset: totalOffset.map { .page($0) },
        progression: progression,
        totalProgression: totalProgression
    )
}
