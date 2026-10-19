//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) @testable import ReadiumShared
@_spi(ExperimentalTimeline) import TestSupport
import Testing

/// Two fixtures are used.
///
/// **Main**: tracks `t1` 600 s, `t2` 300 s and `t3` 900 s.
///
/// - Part 1 → `t1`
///   - Chapter 1 → `t1`
///   - Chapter 2 → `t1#t=300`
/// - Part 2 → `t2#t=60`
///   - Chapter 3 → `t2#t=120`
///   - Chapter 4 → `t3`
///
/// **Sparse**: tracks `t1` 600 s, `t2` 300 s, `t3` 900 s and `t4` 100 s. The
/// TOC starts late, has rangeless entries, and doesn't reference `t4`.
///
/// - A → `t2#t=10`
/// - R → `outside.mp3` (not in the reading order)
///   - C → `t3`
/// - X → `t1` (goes back)
/// - B → `t3#t=200`
enum TimelineTests {
    struct Building {
        @Test func idsArePreOrderIndexesAndItemsKeepTheNodes() {
            #expect(main.timeline.outline == [
                "0 Part 1 → t1",
                "  1 Chapter 1 → t1",
                "  2 Chapter 2 → t1#t=300",
                "3 Part 2 → t2#t=60",
                "  4 Chapter 3 → t2#t=120",
                "  5 Chapter 4 → t3",
            ])
            #expect(main.timeline.preOrderItems.map(\.link) == main.nodes.preOrder.map(\.link))
        }

        @Test func emptyNodesGiveAnEmptyTimeline() {
            let timeline = TimelineFixture(durations: [600, 300, 900], nodes: []).timeline

            #expect(timeline.items.isEmpty)
            #expect(timeline.locate(Locator(href: "t1", mediaType: .mp3)) == nil)
            #expect(timeline.first() == nil)
            #expect(timeline.segments() == [])
            #expect(timeline.segments(in: url("t1")) == [])
        }

        @Test func sparseItemsKeepTheirPlaceWithoutARange() {
            #expect(sparse.timeline.outline == [
                "0 A → t2#t=10",
                "1 R → outside.mp3",
                "  2 C → t3",
                "3 X → t1",
                "4 B → t3#t=200",
            ])
            #expect(sparse.timeline.preOrderItems.map(\.start) == [
                sparse.at(1, 10),
                // Outside the reading order.
                nil,
                // Placed under a rangeless parent.
                sparse.at(2, 0),
                // Goes back.
                nil,
                // Compared with the last placed start (C), not with X.
                sparse.at(2, 200),
            ])
        }

        @Test func childStartingBeforeItsParentIsRangeless() {
            let fixture = TimelineFixture(durations: [600, 300], nodes: [
                node("Parent", "t2", [node("Child", "t1")]),
            ])

            #expect(fixture["Parent"].start != nil)
            #expect(fixture["Child"].start == nil)
            #expect(fixture["Child"].end == nil)
        }

        @Test func itemsAreAllPlaced() {
            #expect(main.timeline.preOrderItems.map(\.start) == [
                // Part 1 and Chapter 1 share a start.
                main.at(0, 0),
                main.at(0, 0),
                main.at(0, 300),
                main.at(1, 60),
                main.at(1, 120),
                main.at(2, 0),
            ])
        }
    }

    struct Ends {
        @Test func itemEndsAtTheNextRangedItemAfterItsSubtree() {
            let publicationEnd = position(2, 900, totalOffset: 1800, progression: 1, totalProgression: 1)

            #expect(main.timeline.preOrderItems.map(\.end) == [
                // Part 1 ends where Chapter 2 does.
                main.at(1, 60),
                // Chapter 1 ends at Chapter 2's start.
                main.at(0, 300),
                // Chapter 2 ends in the next track.
                main.at(1, 60),
                publicationEnd,
                main.at(2, 0),
                publicationEnd,
            ])
        }

        @Test func endsSkipRangelessItems() {
            #expect(sparse.timeline.preOrderItems.map(\.end) == [
                sparse.at(2, 0),
                nil,
                sparse.at(2, 200),
                nil,
                sparse.at(3, 100),
            ])
        }

        @Test func firstOfTwoSiblingsSharingAStartHasAnEmptyRange() {
            let fixture = TimelineFixture(durations: [600], nodes: [node("One", "t1"), node("Two", "t1")])

            #expect(fixture["One"].start == fixture.at(0, 0))
            #expect(fixture["One"].end == fixture.at(0, 0))
        }

        struct PublicationEnd: Sendable, CustomTestStringConvertible {
            let name: String
            let durations: [TimeInterval?]
            let expected: TimelinePosition?

            var testDescription: String {
                name
            }
        }

        @Test(arguments: [
            PublicationEnd(
                name: "the last track duration is unknown",
                durations: [600, 300, nil],
                expected: nil
            ),
            PublicationEnd(
                name: "an earlier duration is unknown but the last one is known",
                durations: [nil, 300, 900],
                expected: position(2, 900, totalOffset: nil, progression: 1, totalProgression: 1)
            ),
        ])
        func endOfThePublication(_ example: PublicationEnd) {
            let fixture = TimelineFixture(durations: example.durations, nodes: [node("One", "t1"), node("Two", "t3")])

            #expect(fixture["Two"].end == example.expected)
            #expect(fixture.timeline.segments().last?.end == example.expected)
            #expect(fixture.timeline.segments(in: url("t3")).last?.end == example.expected)
        }

        /// `Link.duration` can be shorter than the actual track.
        @Test func startPastTheKnownDurationOfATrack() {
            let fixture = TimelineFixture(durations: [600, 300], nodes: [
                node("A", "t1"),
                node("B", "t1#t=700"),
                node("C", "t2"),
                node("D", "t2#t=400"),
            ])

            // D starts past the end of the publication.
            #expect(fixture["D"].end == fixture.at(1, 400))
            #expect(fixture.timeline.segments() == [
                fixture.segment("A", (0, 0), (0, 700)),
                fixture.segment("B", (0, 700), (1, 0)),
                fixture.segment("C", (1, 0), (1, 400)),
            ])
            // Clipped to the end of each track.
            #expect(fixture.timeline.segments(in: url("t1")) == [
                fixture.segment("A", (0, 0), (0, 600)),
            ])
            #expect(fixture.timeline.segments(in: url("t2")) == [
                fixture.segment("C", (1, 0), (1, 300)),
            ])
        }
    }

    struct Equality {
        struct OffsetPair: Sendable, CustomTestStringConvertible {
            let name: String
            let low: TimelineOffset
            let high: TimelineOffset

            var testDescription: String {
                name
            }
        }

        @Test(arguments: [
            OffsetPair(name: "seconds", low: .seconds(10), high: .seconds(20)),
            OffsetPair(name: "scroll", low: .scroll(0.1), high: .scroll(0.2)),
            OffsetPair(name: "page", low: .page(1), high: .page(2)),
        ])
        func positionsAreOrderedByIndexThenByOffset(_ offsets: OffsetPair) {
            func position(_ index: Int, _ offset: TimelineOffset) -> TimelinePosition {
                TimelinePosition(readingOrderIndex: index, offset: offset)
            }

            #expect(position(0, offsets.high).isBefore(position(1, offsets.low)))
            #expect(position(1, offsets.low).isBefore(position(1, offsets.high)))
            #expect(position(1, offsets.high).isBefore(position(2, offsets.low)))
            #expect(!position(1, offsets.low).isBefore(position(1, offsets.low)))
        }

        @Test func itemsOfTimelinesBuiltFromTheSameNodesAreEqual() {
            let other = makeMain()

            #expect(main["Chapter 1"] == other["Chapter 1"])
            #expect(main["Chapter 1"].hashValue == other["Chapter 1"].hashValue)
            #expect(main["Chapter 1"] != main["Chapter 2"])
        }

        /// C has the id of Chapter 2 in Main.
        @Test func queriesIgnoreTheItemsOfAnotherTimeline() {
            #expect(main.timeline.previous(before: sparse["C"]) == nil)
            #expect(main.timeline.next(after: sparse["C"]) == nil)
            #expect(main.timeline.ancestors(of: sparse["C"]) == [])
        }
    }

    struct Locate {
        @Test func returnsTheDeepestItemContainingTheLocator() {
            #expect(main.locate("t1", 450) == main["Chapter 2"])
            // Part 2's gap.
            #expect(main.locate("t2", 90) == main["Part 2"])
            // A start shared by Part 1 and Chapter 1.
            #expect(main.locate("t1", 0) == main["Chapter 1"])
        }

        @Test func stopsAtTheMaxDepth() {
            #expect(main.locate("t2", 200, maxDepth: 1) == main["Part 2"])
            #expect(main.locate("t2", 200, maxDepth: 5) == main["Chapter 3"])
            // R is rangeless.
            #expect(sparse.locate("t3", 100, maxDepth: 1) == nil)
        }

        @Test func coverageOfASparseTimeline() {
            #expect(sparse.locate("t1", 300) == nil)
            // Before A.
            #expect(sparse.locate("t2", 5) == nil)
            #expect(sparse.locate("outside.mp3") == nil)
            // Not referenced by the TOC.
            #expect(sparse.locate("t4", 50) == sparse["B"])
            // Past the known end of the last track.
            #expect(sparse.locate("t4", 150) == sparse["B"])
        }
    }

    struct First {
        @Test func isTheFirstRangedItemInPreOrder() {
            // The outermost of Part 1 and Chapter 1, which share the first
            // start.
            #expect(main.timeline.first() == main["Part 1"])
            #expect(first.timeline.first() == first["C"])
        }

        @Test func stopsAtTheMaxDepth() {
            #expect(first.timeline.first(maxDepth: 1) == first["X"])
        }

        @Test func isNilWhenNoItemIsPlaced() {
            let timeline = TimelineFixture(durations: [600], nodes: [node("R", "outside.mp3")]).timeline

            #expect(timeline.first() == nil)
        }

        /// The first placed item is under a rangeless parent.
        private let first = TimelineFixture(durations: [600, 300], nodes: [
            node("R", "outside.mp3", [node("C", "t1")]),
            node("X", "t2"),
        ])
    }

    struct PreviousAndNext {
        @Test func followThePreOrder() {
            let order = ["Chapter 1", "Chapter 2", "Part 2", "Chapter 3", "Chapter 4"].map { main[$0] }
            for (item, next) in zip(order, order.dropFirst()) {
                #expect(main.timeline.next(after: item) == next)
                #expect(main.timeline.previous(before: next) == item)
            }
            #expect(main.timeline.previous(before: main["Part 1"]) == nil)
            #expect(main.timeline.next(after: main["Chapter 4"]) == nil)
        }

        @Test func skipItemsWithTheSameStart() {
            #expect(main.timeline.next(after: main["Part 1"]) == main["Chapter 2"])
            #expect(main.timeline.previous(before: main["Chapter 1"]) == nil)
        }

        @Test func rangelessItemsUseTheirPlaceInThePreOrder() {
            #expect(sparse.timeline.next(after: sparse["A"]) == sparse["C"])
            #expect(sparse.timeline.next(after: sparse["R"]) == sparse["C"])
            #expect(sparse.timeline.previous(before: sparse["X"]) == sparse["C"])
            #expect(sparse.timeline.next(after: sparse["X"]) == sparse["B"])
        }

        @Test func stopAtTheMaxDepth() {
            #expect(main.timeline.next(after: main["Chapter 2"], maxDepth: 1) == main["Part 2"])
            // The containing part, as it compares with the start of the given
            // item.
            #expect(main.timeline.previous(before: main["Chapter 3"], maxDepth: 1) == main["Part 2"])
        }

        @Test(arguments: [0, -1])
        func maxDepthBelowOneReturnsNothing(maxDepth: Int) {
            #expect(main.locate("t1", 450, maxDepth: maxDepth) == nil)
            #expect(main.timeline.first(maxDepth: maxDepth) == nil)
            #expect(main.timeline.previous(before: main["Chapter 2"], maxDepth: maxDepth) == nil)
            #expect(main.timeline.next(after: main["Chapter 2"], maxDepth: maxDepth) == nil)
            #expect(main.timeline.segments(maxDepth: maxDepth) == [])
            #expect(main.timeline.segments(in: url("t1"), maxDepth: maxDepth) == [])
        }
    }

    struct Ancestors {
        @Test func goFromTheTopLevelToTheParent() {
            #expect(main.timeline.ancestors(of: main["Part 1"]) == [])
            #expect(main.timeline.ancestors(of: main["Chapter 3"]) == [main["Part 2"]])
            #expect(sparse.timeline.ancestors(of: sparse["C"]) == [sparse["R"]])
        }
    }

    struct Segments {
        @Test func coverTheTimelineWithTheDeepestItems() {
            #expect(main.timeline.segments() == [
                // Part 1's segment is empty.
                main.segment("Chapter 1", (0, 0), (0, 300)),
                main.segment("Chapter 2", (0, 300), (1, 60)),
                main.segment("Part 2", (1, 60), (1, 120)),
                main.segment("Chapter 3", (1, 120), (2, 0)),
                main.segment("Chapter 4", (2, 0), (2, 900)),
            ])
        }

        @Test func stopAtTheMaxDepth() {
            #expect(main.timeline.segments(maxDepth: 1) == [
                main.segment("Part 1", (0, 0), (1, 60)),
                main.segment("Part 2", (1, 60), (2, 900)),
            ])
        }

        @Test func skipTheGapsOfASparseTimeline() {
            #expect(sparse.timeline.segments() == [
                sparse.segment("A", (1, 10), (2, 0)),
                sparse.segment("C", (2, 0), (2, 200)),
                sparse.segment("B", (2, 200), (3, 100)),
            ])
            // `[t3 0, t3 200)` has no segment, as `locate` returns nil there.
            #expect(sparse.timeline.segments(maxDepth: 1) == [
                sparse.segment("A", (1, 10), (2, 0)),
                sparse.segment("B", (2, 200), (3, 100)),
            ])
        }

        struct FixtureDepth: Sendable, CustomTestStringConvertible {
            let name: String
            let fixture: TimelineFixture
            let maxDepth: Int?

            var testDescription: String {
                name
            }
        }

        /// `locate` returns the item of a segment at its start and 1 ms before
        /// its end.
        @Test(arguments: [
            FixtureDepth(name: "main", fixture: main, maxDepth: nil),
            FixtureDepth(name: "main at depth 1", fixture: main, maxDepth: 1),
            FixtureDepth(name: "sparse", fixture: sparse, maxDepth: nil),
            FixtureDepth(name: "sparse at depth 1", fixture: sparse, maxDepth: 1),
        ])
        func labelsMatchLocate(_ example: FixtureDepth) {
            let fixture = example.fixture
            for segment in fixture.timeline.segments(maxDepth: example.maxDepth) {
                #expect(fixture.locate(segment.start, maxDepth: example.maxDepth) == segment.item)
                #expect(fixture.locate(segment.end!, by: -0.001, maxDepth: example.maxDepth) == segment.item)
            }
        }
    }

    struct SegmentsInResource {
        @Test func areClippedToTheResource() {
            #expect(main.timeline.segments(in: url("t1")) == [
                main.segment("Chapter 1", (0, 0), (0, 300)),
                main.segment("Chapter 2", (0, 300), (0, 600)),
            ])
            #expect(main.timeline.segments(in: url("t2")) == [
                main.segment("Chapter 2", (1, 0), (1, 60)),
                main.segment("Part 2", (1, 60), (1, 120)),
                main.segment("Chapter 3", (1, 120), (1, 300)),
            ])
            // No empty Chapter 3.
            #expect(main.timeline.segments(in: url("t3")) == [
                main.segment("Chapter 4", (2, 0), (2, 900)),
            ])
        }

        @Test func ofASparseTimeline() {
            #expect(sparse.timeline.segments(in: url("t1")) == [])
            #expect(sparse.timeline.segments(in: url("t2")) == [
                sparse.segment("A", (1, 10), (1, 300)),
            ])
        }

        @Test func endIsNilWhenTheTrackDurationIsUnknown() {
            let fixture = TimelineFixture(durations: [600, nil, 900], nodes: makeMain().nodes)

            #expect(fixture.timeline.segments(in: url("t2")).last?.item == fixture["Chapter 3"])
            #expect(fixture.timeline.segments(in: url("t2")).last?.end == nil)
        }

        @Test func hrefIsResolvedInTheReadingOrder() {
            #expect(main.timeline.segments(in: url("t2#t=60")) == main.timeline.segments(in: url("t2")))
            #expect(main.timeline.segments(in: url("outside.mp3")) == [])
        }

        @Test func stopAtTheMaxDepth() {
            #expect(main.timeline.segments(in: url("t2"), maxDepth: 1) == [
                main.segment("Part 1", (1, 0), (1, 60)),
                main.segment("Part 2", (1, 60), (1, 300)),
            ])
        }
    }
}

// MARK: - Helpers

private let main = makeMain()
private let sparse = makeSparse()

private func makeMain() -> TimelineFixture {
    TimelineFixture(durations: [600, 300, 900], nodes: [
        node("Part 1", "t1", [
            node("Chapter 1", "t1"),
            node("Chapter 2", "t1#t=300"),
        ]),
        node("Part 2", "t2#t=60", [
            node("Chapter 3", "t2#t=120"),
            node("Chapter 4", "t3"),
        ]),
    ])
}

private func makeSparse() -> TimelineFixture {
    TimelineFixture(durations: [600, 300, 900, 100], nodes: [
        node("A", "t2#t=10"),
        node("R", "outside.mp3", [node("C", "t3")]),
        node("X", "t1"),
        node("B", "t3#t=200"),
    ])
}

private func node(_ title: String, _ href: String, _ children: [Timeline.Node] = []) -> Timeline.Node {
    Timeline.Node(title: .text(title), link: Link(href: href), children: children)
}

private func url(_ string: String) -> AnyURL {
    AnyURL(string: string)!
}

private func position(
    _ index: Int,
    _ offset: TimeInterval,
    totalOffset: TimeInterval?,
    progression: Double?,
    totalProgression: Double?
) -> TimelinePosition {
    TimelinePosition(
        readingOrderIndex: index,
        offset: .seconds(offset),
        totalOffset: totalOffset.map { .seconds($0) },
        progression: progression,
        totalProgression: totalProgression
    )
}

/// A timeline built from tracks named `t1`, `t2` and so on.
struct TimelineFixture: Sendable {
    let durations: [TimeInterval?]
    let readingOrder: [Link]
    let nodes: [Timeline.Node]
    let timeline: Timeline

    init(durations: [TimeInterval?], nodes: [Timeline.Node]) {
        self.durations = durations
        readingOrder = durations.enumerated().map { index, duration in
            Link(href: "t\(index + 1)", mediaType: .mp3, duration: duration)
        }
        self.nodes = nodes
        timeline = Timeline(nodes: nodes, resolver: AudioTimelinePositionResolver(readingOrder: readingOrder))
    }

    /// Returns the item with the given title.
    subscript(title: String) -> TimelineItem {
        timeline.preOrderItems.first { $0.title == .text(title) }!
    }

    /// Returns the position at `offset` in the track at `index`, when all the
    /// durations are known.
    func at(_ index: Int, _ offset: TimeInterval) -> TimelinePosition {
        let durations = durations.map { $0! }
        let totalOffset = durations[..<index].reduce(0, +) + offset
        return position(
            index,
            offset,
            totalOffset: totalOffset,
            progression: offset / durations[index],
            totalProgression: totalOffset / durations.reduce(0, +)
        )
    }

    /// Returns the segment of the item with the given title, between the
    /// given track indexes and offsets.
    func segment(_ title: String, _ start: (Int, TimeInterval), _ end: (Int, TimeInterval)) -> TimelineSegment {
        TimelineSegment(item: self[title], start: at(start.0, start.1), end: at(end.0, end.1))
    }

    func locate(_ href: String, _ offset: TimeInterval? = nil, maxDepth: Int? = nil) -> TimelineItem? {
        let fragments = offset.map { ["t=\($0)"] } ?? []
        return timeline.locate(Locator(href: href, mediaType: .mp3, locations: .init(fragments: fragments)), maxDepth: maxDepth)
    }

    /// Locates the position moved by `delta` seconds, possibly in the
    /// previous track.
    func locate(_ position: TimelinePosition, by delta: TimeInterval = 0, maxDepth: Int? = nil) -> TimelineItem? {
        var index = position.readingOrderIndex
        var offset = position.offset.seconds + delta
        if offset < 0 {
            index -= 1
            offset += durations[index]!
        }
        return locate("t\(index + 1)", offset, maxDepth: maxDepth)
    }
}

private extension Timeline {
    /// All the items, in pre-order.
    var preOrderItems: [TimelineItem] {
        items.preOrder
    }
}

private extension [TimelineItem] {
    var preOrder: [TimelineItem] {
        flatMap { [$0] + $0.children.preOrder }
    }
}

private extension [Timeline.Node] {
    var preOrder: [Timeline.Node] {
        flatMap { [$0] + $0.children.preOrder }
    }
}

private extension TimelineOffset {
    var seconds: TimeInterval {
        guard case let .seconds(seconds) = self else {
            fatalError("Expected an offset in seconds, got \(self)")
        }
        return seconds
    }
}
