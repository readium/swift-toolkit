//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) @testable import ReadiumShared
import Testing
@_spi(ExperimentalTimeline) import TestSupport

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
///
/// **Nested**: tracks `t1` 600 s and `t2` 300 s. A placed entry is nested
/// under a rangeless one.
///
/// - Part 1 → `t1`
///   - Chapter 1 → `t1`
///   - Chapter 2 → `outside.mp3` (not in the reading order)
///     - Section → `t1#t=300`
/// - Part 2 → `t2`
///
/// **Split**: track `t1` 600 s. At depth 2, Chapter 1 splits the segments of
/// Part.
///
/// - Part → `t1`
///   - Chapter 1 → `t1#t=100`
///   - Chapter 2 → `outside.mp3` (not in the reading order)
///     - Section → `t1#t=300`
enum TimelineTests {
    struct Building {
        @Test func idsWrapPreOrderIndicesAndEntriesKeepTheNodes() {
            #expect(main.timeline.outline == [
                "0 Part 1 → t1",
                "  1 Chapter 1 → t1",
                "  2 Chapter 2 → t1#t=300",
                "3 Part 2 → t2#t=60",
                "  4 Chapter 3 → t2#t=120",
                "  5 Chapter 4 → t3",
            ])
            #expect(main.timeline.preOrderEntries.map(\.link) == main.nodes.preOrder.map(\.link))
        }

        @Test func emptyNodesGiveATimelineWithoutEntries() {
            #expect(noTOC.timeline.toc.isEmpty)
        }

        @Test func sparseEntriesKeepTheirPlaceWithoutARange() {
            #expect(sparse.timeline.outline == [
                "0 A → t2#t=10",
                "1 R → outside.mp3",
                "  2 C → t3",
                "3 X → t1",
                "4 B → t3#t=200",
            ])
            #expect(sparse.timeline.preOrderEntries.map(\.start) == [
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

        @Test func entriesAreAllPlaced() {
            #expect(main.timeline.preOrderEntries.map(\.start) == [
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
        @Test func entryEndsAtTheNextRangedEntryAfterItsSubtree() {
            let publicationEnd = position(2, 900, time: 1800, progression: 1, totalProgression: 1)

            #expect(main.timeline.preOrderEntries.map(\.end) == [
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

        @Test func endsSkipRangelessEntries() {
            #expect(sparse.timeline.preOrderEntries.map(\.end) == [
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
                expected: position(2, 900, time: nil, progression: 1, totalProgression: 1)
            ),
        ])
        func endOfThePublication(_ example: PublicationEnd) {
            let fixture = TimelineFixture(durations: example.durations, nodes: [node("One", "t1"), node("Two", "t3")])

            #expect(fixture["Two"].end == example.expected)
            #expect(fixture.timeline.segments().last?.end == example.expected)
            #expect(TimelineFixture(durations: example.durations, nodes: []).timeline.segments().last?.end == example.expected)
            #expect(fixture.timeline.segments().segments(in: url("t3")).last?.end == example.expected)
        }

        @Test func emptyReadingOrderHasNoEnd() {
            #expect(AudioTimelinePositionResolver(readingOrder: []).end == nil)
        }

        /// `Link.duration` can be shorter than the actual track.
        @Test func startPastTheKnownDurationOfATrack() {
            let fixture = TimelineFixture(durations: [600, 300], nodes: [
                node("A", "t1"),
                node("B", "t1#t=700"),
                node("C", "t2"),
                node("D", "t2#t=400"),
            ])

            // B's length is unknown, as `t1` is longer than its duration.
            #expect(fixture["B"].length == nil)
            // D starts past the end of the publication.
            #expect(fixture["D"].end == fixture.at(1, 400))
            #expect(fixture["D"].length == .duration(0))
            #expect(Array(fixture.timeline.segments()) == [
                fixture.segment("A", (0, 0), (0, 700)),
                fixture.segment("B", (0, 700), (1, 0)),
                fixture.segment("C", (1, 0), (1, 400)),
            ])
            // Clipped to the end of each track.
            #expect(fixture.timeline.segments().segments(in: url("t1")) == [
                fixture.segment("A", (0, 0), (0, 600)),
            ])
            #expect(fixture.timeline.segments().segments(in: url("t2")) == [
                fixture.segment("C", (1, 0), (1, 300)),
            ])
            // D has no segment: past the end of C, the segment is still C.
            #expect(fixture.segment(containing: "t2", 450) == fixture.segment("C", (1, 0), (1, 400)))
        }
    }

    struct Lengths {
        @Test func lengthGoesFromTheStartToTheEnd() {
            #expect(main.timeline.preOrderEntries.map(\.length) == [660, 300, 360, 1140, 180, 900].map { .duration($0) })
        }

        @Test func rangelessEntriesHaveNoLength() {
            #expect(sparse.timeline.preOrderEntries.map(\.length) == [.duration(290), nil, .duration(200), nil, .duration(800)])
        }

        /// One continues past `t1`, whose duration is unknown, and Three has
        /// no end.
        @Test func lengthIsUnknownPastAnUnknownDurationOrWithoutAnEnd() {
            let fixture = TimelineFixture(durations: [nil, 300, nil], nodes: [
                node("One", "t1"),
                node("Two", "t2"),
                node("Three", "t3"),
            ])

            #expect(fixture.timeline.toc.entries.map(\.length) == [nil, .duration(300), nil])
        }
    }

    struct Equality {
        /// Unlike equality, the coordinates are ignored.
        @Test func positionsAreOrderedByIndexThenByOffset() {
            func position(_ index: Int, _ offset: Double, _ coordinate: TimelineCoordinate? = nil) -> TimelinePosition {
                TimelinePosition(readingOrderIndex: index, offset: offset, coordinate: coordinate)
            }

            #expect(position(0, 20).isBefore(position(1, 10)))
            #expect(!position(1, 10).isBefore(position(0, 20)))
            #expect(position(1, 10).isBefore(position(1, 20)))
            #expect(!position(1, 10).isBefore(position(1, 10)))
            #expect(position(1, 10, .page(9)).isBefore(position(1, 20, .page(1))))

            let (a, b) = (position(1, 10, .page(1)), position(1, 10, .page(2)))
            #expect(a != b)
            #expect(!a.isBefore(b) && !b.isBefore(a))
        }

        @Test func entriesOfTimelinesBuiltFromTheSameNodesAreEqual() {
            let other = makeMain()

            #expect(main["Chapter 1"] == other["Chapter 1"])
            #expect(main["Chapter 1"].hashValue == other["Chapter 1"].hashValue)
            #expect(main["Chapter 1"] != main["Chapter 2"])
        }
    }

    /// See also `findsEachSegment` in `Segments`, at the start and end of
    /// each segment.
    struct SegmentContaining {
        /// Part 2's segment ends at Chapter 3, unlike Part 2.
        @Test func endsWhereTheNextEntryStarts() {
            #expect(main.segment(containing: "t2", 90) == main.segment("Part 2", (1, 60), (1, 120)))
        }

        @Test func isNilOutsideTheReadingOrder() {
            #expect(sparse.segment(containing: "outside.mp3") == nil)
        }

        /// Past the known end of the last track, the segment of B ends before
        /// the locator.
        @Test func pastTheKnownEndOfThePublication() {
            #expect(sparse.segment(containing: "t4", 150) == sparse.segment("B", (2, 200), (3, 100)))
        }

        @Test func isTheLastSegmentWhenItsEndIsUnknown() {
            let fixture = TimelineFixture(durations: [600, 300, nil], nodes: makeMain().nodes)
            #expect(fixture.segment(containing: "t3", 5000) == fixture.timeline.segments().last)
        }
    }

    struct SegmentBeforeAndAfter {
        @Test func areTheNeighborsOfTheSegment() {
            let segments = main.timeline.segments()

            #expect(segments.segment(before: segments[1]) == segments[0])
            #expect(segments.segment(after: segments[1]) == segments[2])
        }

        @Test func areNilAtTheEnds() {
            let segments = main.timeline.segments()

            #expect(segments.segment(before: segments[0]) == nil)
            #expect(segments.segment(after: segments[segments.count - 1]) == nil)
        }

        /// Chapter 3 is located by its start, in Part 2.
        @Test func acceptASegmentOfAnotherMaxDepth() {
            let chapter3 = main.segment("Chapter 3", (1, 120), (2, 0))
            let parts = main.timeline.segments(maxDepth: 1)

            #expect(parts.segment(before: chapter3) == main.segment("Part 1", (0, 0), (1, 60)))
            #expect(parts.segment(after: chapter3) == nil)
        }

        /// Chapter 2 clipped to `t2` is located by its start, in Chapter 2.
        @Test func acceptACopyClippedToAResource() throws {
            let segments = main.timeline.segments()
            let clipped = try #require(segments.segments(in: url("t2")).first)

            #expect(segments.segment(before: clipped) == main.segment("Chapter 1", (0, 0), (0, 300)))
            #expect(segments.segment(after: clipped) == main.segment("Part 2", (1, 60), (1, 120)))
        }
    }

    struct Position {
        @Test func resolvesTheLocator() {
            #expect(main.timeline.position(of: Locator(href: "t2", mediaType: .mp3, locations: .init(fragments: ["t=60"]))) == main.at(1, 60))
            #expect(main.timeline.position(of: Locator(href: "outside.mp3", mediaType: .mp3)) == nil)
        }
    }

    struct Length {
        @Test func measuresTheResolverLengthBetweenTwoPositions() {
            #expect(main.timeline.length(from: main.at(0, 500), to: main.at(1, 60)) == .duration(160))
        }

        @Test func accessorsReadTheValueInTheirUnit() {
            #expect(TimelineLength.duration(-1.5).seconds == -1.5)
            #expect(TimelineLength.duration(1.5).count == nil)
            #expect(TimelineLength.pages(-3).count == -3)
            #expect(TimelineLength.positions(3).count == 3)
            #expect(TimelineLength.positions(3).seconds == nil)
        }
    }

    struct Path {
        @Test func isTheEntryAloneAtTheTopLevel() {
            #expect(main.timeline.toc.path(to: main["Part 1"]) == [main["Part 1"]])
        }

        /// Chapter 2 is not in the reading order.
        @Test func goesFromTheTopLevelDownToTheEntryThroughTheUnplacedAncestors() {
            #expect(nested.timeline.toc.path(to: nested["Section"]) == [nested["Part 1"], nested["Chapter 2"], nested["Section"]])
        }
    }

    struct Segments {
        @Test func coverTheTimelineWithTheDeepestEntries() {
            #expect(Array(main.timeline.segments()) == [
                // Part 1's segment is empty.
                main.segment("Chapter 1", (0, 0), (0, 300)),
                main.segment("Chapter 2", (0, 300), (1, 60)),
                main.segment("Part 2", (1, 60), (1, 120)),
                main.segment("Chapter 3", (1, 120), (2, 0)),
                main.segment("Chapter 4", (2, 0), (2, 900)),
            ])
        }

        @Test func stopAtTheMaxDepth() {
            #expect(Array(main.timeline.segments(maxDepth: 1)) == [
                main.segment("Part 1", (0, 0), (1, 60)),
                main.segment("Part 2", (1, 60), (2, 900)),
            ])
        }

        @Test(arguments: [0, -1])
        func maxDepthBelowOneGivesNoEntry(maxDepth: Int) {
            #expect(Array(main.timeline.segments(maxDepth: maxDepth)) == Array(noTOC.timeline.segments()))
            #expect(main.timeline.segments(maxDepth: maxDepth).segments(in: url("t1")) == noTOC.timeline.segments().segments(in: url("t1")))
        }

        /// The tracks without entry are not merged.
        @Test func haveOneSegmentWithoutEntryPerTrackWithoutTableOfContents() {
            #expect(Array(noTOC.timeline.segments()) == [
                noTOC.segment(nil, (0, 0), (1, 0)),
                noTOC.segment(nil, (1, 0), (2, 0)),
                noTOC.segment(nil, (2, 0), (2, 900)),
            ])
        }

        /// Each track has a segment, even when it repeats the HREF of a
        /// previous one.
        @Test func haveOneSegmentWithoutEntryPerTrackRepeatingAnHREF() {
            let readingOrder = [Link(href: "t1", mediaType: .mp3, duration: 600), Link(href: "t1", mediaType: .mp3, duration: 300)]
            let timeline = Timeline(nodes: [], resolver: AudioTimelinePositionResolver(readingOrder: readingOrder))

            #expect(timeline.segments().map(\.link) == readingOrder)
        }

        /// A starts partway into `t2`.
        @Test func haveOneSegmentWithoutEntryPerTrackBeforeTheFirstEntry() {
            #expect(Array(sparse.timeline.segments()) == [
                sparse.segment(nil, (0, 0), (1, 0)),
                sparse.segment(nil, (1, 0), (1, 10)),
                sparse.segment("A", (1, 10), (2, 0)),
                sparse.segment("C", (2, 0), (2, 200)),
                sparse.segment("B", (2, 200), (3, 100)),
            ])
        }

        /// No entry contains `[t3 0, t3 200)` within `maxDepth`, where C is
        /// deeper than `maxDepth` under the rangeless R. Partway into a
        /// track, the segment links to C.
        @Test func haveNoEntryWhereOnlyADeeperEntryUnderARangelessOneIsPlaced() {
            #expect(Array(sparse.timeline.segments(maxDepth: 1)) == [
                sparse.segment(nil, (0, 0), (1, 0)),
                sparse.segment(nil, (1, 0), (1, 10)),
                sparse.segment("A", (1, 10), (2, 0)),
                sparse.segment(nil, (2, 0), (2, 200)),
                sparse.segment("B", (2, 200), (3, 100)),
            ])

            let partway = TimelineFixture(durations: [600], nodes: [
                node("A", "t1"),
                node("R", "outside.mp3", [node("C", "t1#t=300")]),
            ])
            #expect(Array(partway.timeline.segments(maxDepth: 1)) == [
                partway.segment("A", (0, 0), (0, 300)),
                partway.segment(nil, (0, 300), (0, 600), link: partway["C"].link),
            ])
        }

        @Test func ancestorKeepsTheRangeOfADeeperEntryUnderARangelessOne() {
            #expect(Array(nested.timeline.segments()) == [
                nested.segment("Chapter 1", (0, 0), (0, 300)),
                nested.segment("Section", (0, 300), (1, 0)),
                nested.segment("Part 2", (1, 0), (1, 300)),
            ])
            // Part 1 contains `[t1 300, t2 0)` within `maxDepth`. The range
            // starts at Section, hence its link.
            #expect(Array(nested.timeline.segments(maxDepth: 2)) == [
                nested.segment("Chapter 1", (0, 0), (0, 300)),
                nested.segment("Part 1", (0, 300), (1, 0), link: nested["Section"].link),
                nested.segment("Part 2", (1, 0), (1, 300)),
            ])
            #expect(Array(nested.timeline.segments(maxDepth: 1)) == [
                nested.segment("Part 1", (0, 0), (1, 0)),
                nested.segment("Part 2", (1, 0), (1, 300)),
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

        /// `segment(containing:)` returns each segment at its start and 1 ms
        /// before its end.
        @Test(arguments: [
            FixtureDepth(name: "main", fixture: main, maxDepth: nil),
            FixtureDepth(name: "main at depth 1", fixture: main, maxDepth: 1),
            FixtureDepth(name: "main deeper than its entries", fixture: main, maxDepth: 5),
            FixtureDepth(name: "without table of contents", fixture: noTOC, maxDepth: nil),
            FixtureDepth(name: "sparse", fixture: sparse, maxDepth: nil),
            FixtureDepth(name: "sparse at depth 1", fixture: sparse, maxDepth: 1),
            FixtureDepth(name: "nested", fixture: nested, maxDepth: nil),
            FixtureDepth(name: "nested at depth 2", fixture: nested, maxDepth: 2),
            FixtureDepth(name: "split at depth 2", fixture: split, maxDepth: 2),
        ])
        func findsEachSegment(_ example: FixtureDepth) {
            let fixture = example.fixture
            let segments = fixture.timeline.segments(maxDepth: example.maxDepth)
            for segment in segments {
                for locator in [fixture.locator(at: segment.start), fixture.locator(at: segment.end!, by: -0.001)] {
                    #expect(segments.segment(containing: locator) == segment)
                }
            }
        }
    }

    struct SegmentsInResource {
        /// A segment clipped at the start of the resource links to it.
        @Test func areClippedToTheResource() {
            #expect(main.timeline.segments().segments(in: url("t1")) == [
                main.segment("Chapter 1", (0, 0), (0, 300)),
                main.segment("Chapter 2", (0, 300), (0, 600)),
            ])
            #expect(main.timeline.segments().segments(in: url("t2")) == [
                main.segment("Chapter 2", (1, 0), (1, 60), link: main.readingOrder[1]),
                main.segment("Part 2", (1, 60), (1, 120)),
                main.segment("Chapter 3", (1, 120), (1, 300)),
            ])
            // No empty Chapter 3.
            #expect(main.timeline.segments().segments(in: url("t3")) == [
                main.segment("Chapter 4", (2, 0), (2, 900)),
            ])
        }

        @Test func ofASparseTimeline() {
            #expect(sparse.timeline.segments().segments(in: url("t1")) == [
                sparse.segment(nil, (0, 0), (0, 600)),
            ])
            #expect(sparse.timeline.segments().segments(in: url("t2")) == [
                sparse.segment(nil, (1, 0), (1, 10)),
                sparse.segment("A", (1, 10), (1, 300)),
            ])
        }

        @Test func endIsNilWhenTheTrackDurationIsUnknown() {
            let fixture = TimelineFixture(durations: [600, nil, 900], nodes: makeMain().nodes)

            #expect(fixture.timeline.segments().segments(in: url("t2")).last?.tocEntry == fixture["Chapter 3"])
            #expect(fixture.timeline.segments().segments(in: url("t2")).last?.end == nil)
        }

        @Test func hrefIsResolvedInTheReadingOrder() {
            #expect(main.timeline.segments().segments(in: url("t2#t=60")) == main.timeline.segments().segments(in: url("t2")))
            #expect(main.timeline.segments().segments(in: url("outside.mp3")) == [])
        }

        @Test func stopAtTheMaxDepth() {
            #expect(main.timeline.segments(maxDepth: 1).segments(in: url("t2")) == [
                main.segment("Part 1", (1, 0), (1, 60), link: main.readingOrder[1]),
                main.segment("Part 2", (1, 60), (1, 300)),
            ])
        }
    }
}

// MARK: - Helpers

private let main = makeMain()
private let noTOC = TimelineFixture(durations: [600, 300, 900], nodes: [])
private let sparse = makeSparse()
private let nested = makeNested()
private let split = makeSplit()

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

private func makeNested() -> TimelineFixture {
    TimelineFixture(durations: [600, 300], nodes: [
        node("Part 1", "t1", [
            node("Chapter 1", "t1"),
            node("Chapter 2", "outside.mp3", [node("Section", "t1#t=300")]),
        ]),
        node("Part 2", "t2"),
    ])
}

private func makeSplit() -> TimelineFixture {
    TimelineFixture(durations: [600], nodes: [
        node("Part", "t1", [
            node("Chapter 1", "t1#t=100"),
            node("Chapter 2", "outside.mp3", [node("Section", "t1#t=300")]),
        ]),
    ])
}

private func node(_ title: String, _ href: String, _ children: [Timeline.Node] = []) -> Timeline.Node {
    Timeline.Node(title: title, link: Link(href: href), children: children)
}

private func url(_ string: String) -> AnyURL {
    AnyURL(string: string)!
}

private func position(
    _ index: Int,
    _ offset: TimeInterval,
    time: TimeInterval?,
    progression: Double?,
    totalProgression: Double?
) -> TimelinePosition {
    TimelinePosition(
        readingOrderIndex: index,
        offset: offset,
        coordinate: time.map { .time($0) },
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

    /// Returns the entry with the given title.
    subscript(title: String) -> TimelineTOCEntry {
        timeline.preOrderEntries.first { $0.title == title }!
    }

    /// Returns the position at `offset` in the track at `index`, when all the
    /// durations are known.
    func at(_ index: Int, _ offset: TimeInterval) -> TimelinePosition {
        let durations = durations.map { $0! }
        let time = durations[..<index].reduce(0, +) + offset
        return position(
            index,
            offset,
            time: time,
            progression: offset / durations[index],
            totalProgression: time / durations.reduce(0, +)
        )
    }

    /// Returns the segment of the entry with the given title, or without
    /// entry, between the given track indexes and offsets.
    ///
    /// - Parameter link: Defaults to the link of the entry, or of the track
    ///   of `start` without entry.
    func segment(
        _ title: String?,
        _ start: (Int, TimeInterval),
        _ end: (Int, TimeInterval),
        link: Link? = nil
    ) -> TimelineSegment {
        let entry = title.map { self[$0] }
        return TimelineSegment(
            tocEntry: entry,
            link: link ?? entry?.link ?? readingOrder[start.0],
            start: at(start.0, start.1),
            end: at(end.0, end.1)
        )
    }

    func segment(containing href: String, _ offset: TimeInterval? = nil) -> TimelineSegment? {
        timeline.segments().segment(containing: locator(href, offset))
    }

    /// Returns the locator at `offset` seconds in the track `href`.
    func locator(_ href: String, _ offset: TimeInterval? = nil) -> Locator {
        let fragments = offset.map { ["t=\($0)"] } ?? []
        return Locator(href: href, mediaType: .mp3, locations: .init(fragments: fragments))
    }

    /// Returns the locator of the position moved by `delta` seconds, possibly
    /// in the previous track.
    func locator(at position: TimelinePosition, by delta: TimeInterval = 0) -> Locator {
        var index = position.readingOrderIndex
        var offset = position.offset + delta
        if offset < 0 {
            index -= 1
            offset += durations[index]!
        }
        return locator("t\(index + 1)", offset)
    }
}

private extension Timeline {
    /// All the entries, in pre-order.
    var preOrderEntries: [TimelineTOCEntry] {
        toc.entries.preOrder
    }
}

private extension [TimelineTOCEntry] {
    var preOrder: [TimelineTOCEntry] {
        flatMap { [$0] + $0.children.preOrder }
    }
}

private extension [Timeline.Node] {
    var preOrder: [Timeline.Node] {
        flatMap { [$0] + $0.children.preOrder }
    }
}
