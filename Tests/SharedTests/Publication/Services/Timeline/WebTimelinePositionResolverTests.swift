//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) @testable import ReadiumShared
import Testing

/// Reading order: `a`, `b` and `c`, of 4, 2 and 4 positions unless a test
/// gives other counts, each with a table of contents entry.
enum WebTimelinePositionResolverTests {
    struct Links {
        @Test func linkIsPlacedAtTheStartOfItsResource() {
            #expect(resolver().position(of: Link(href: "b")) == TimelinePosition(
                readingOrderIndex: 1,
                offset: 0,
                coordinate: .position(5),
                progression: 0,
                totalProgression: 0.4
            ))
        }
    }

    /// All the locators are in `c`, at positions 7 to 10.
    struct Locators {
        struct LocatorCoordinate: Sendable, CustomTestStringConvertible {
            let name: String
            var positionCounts: [Int?] = [4, 2, 4]
            let locations: Locator.Locations
            let expected: Int?

            var testDescription: String {
                name
            }
        }

        @Test(arguments: [
            LocatorCoordinate(name: "a progression is rounded down", locations: .init(progression: 0.6), expected: 9),
            LocatorCoordinate(name: "a progression of 1 is the last position of the resource", locations: .init(progression: 1), expected: 10),
            LocatorCoordinate(name: "a progression past 1 is the last position", locations: .init(progression: 1e300), expected: 10),
            LocatorCoordinate(name: "a negative progression is the first position", locations: .init(progression: -1), expected: 7),
            LocatorCoordinate(name: "no location is the first position", locations: .init(), expected: 7),
            LocatorCoordinate(name: "the position wins over the progression", locations: .init(progression: 0, position: 9), expected: 9),
            LocatorCoordinate(name: "a position outside the resource is ignored", locations: .init(progression: 0, position: 3), expected: 7),
            LocatorCoordinate(name: "a progression needs the count of the resource", positionCounts: [4, 2, nil], locations: .init(progression: 0.6), expected: nil),
            LocatorCoordinate(name: "a position is not bounded when the count of the resource is unknown", positionCounts: [4, 2, nil], locations: .init(position: 20), expected: 20),
            LocatorCoordinate(name: "a preceding count is unknown", positionCounts: [nil, 2, 4], locations: .init(position: 9), expected: nil),
            LocatorCoordinate(name: "a count of 0 is unknown", positionCounts: [4, 0, 4], locations: .init(position: 9), expected: nil),
        ])
        func locatorIsTurnedIntoACoordinate(_ example: LocatorCoordinate) throws {
            let position = try #require(resolver(example.positionCounts).position(of: locator("c", example.locations)))

            #expect(position.coordinate == example.expected.map { .position($0) })
        }

        @Test func progressionInThePublicationIsContinuous() {
            #expect(resolver().position(of: locator("c", .init(progression: 0.625))) == TimelinePosition(
                readingOrderIndex: 2,
                offset: 0.625,
                coordinate: .position(9),
                progression: 0.625,
                totalProgression: 0.85
            ))
        }

        @Test(arguments: [(-1, 0, 0.6), (1e300, 1, 1)])
        func progressionIsClamped(_ progression: Double, _ clamped: Double, _ totalProgression: Double) throws {
            let position = try #require(resolver().position(of: locator("c", .init(progression: progression))))

            #expect(position.offset == clamped)
            #expect(position.progression == clamped)
            #expect(position.totalProgression == totalProgression)
        }

        /// The coordinates before the unknown count are known.
        @Test func progressionInThePublicationIsUnknownWithAnUnknownCount() {
            let position = resolver([4, 2, nil]).position(of: locator("a", .init(progression: 0.5)))

            #expect(position?.coordinate == .position(3))
            #expect(position?.progression == 0.5)
            #expect(position?.totalProgression == nil)
        }

        @Test func locatorOutsideTheReadingOrderHasNoPosition() {
            #expect(resolver().position(of: locator("outside", .init())) == nil)
        }
    }

    struct Ends {
        @Test func endIsOnePastTheLastPosition() {
            #expect(resolver().bounds(ofResource: AnyURL(string: "b")!)?.end == TimelinePosition(
                readingOrderIndex: 1,
                offset: 1,
                coordinate: .position(7),
                progression: 1,
                totalProgression: 0.6
            ))
            #expect(resolver().end?.coordinate == .position(11))
            #expect(resolver().end?.totalProgression == 1)
        }

        @Test func onlyTheEndDependsOnTheCountOfTheResource() throws {
            let bounds = try #require(resolver([4, 2, nil]).bounds(ofResource: AnyURL(string: "c")!))

            #expect(bounds.start.coordinate == .position(7))
            #expect(bounds.end?.coordinate == nil)
        }
    }

    struct Lengths {
        struct LengthExample: Sendable, CustomTestStringConvertible {
            let name: String
            var positionCounts: [Int?] = [4, 2, 4]
            let start: TimelinePosition
            let end: TimelinePosition?
            let expected: Int?

            var testDescription: String {
                name
            }
        }

        @Test(arguments: [
            LengthExample(name: "between the starts of two resources", start: at(0, 0), end: at(2, 0), expected: 6),
            LengthExample(name: "up to the end of a resource", start: at(1, 0), end: at(2, 1), expected: 6),
            LengthExample(name: "a progression is rounded down", start: at(2, 0.6), end: at(2, 1), expected: 2),
            LengthExample(name: "an unknown count before the start does not matter", positionCounts: [nil, 2, 4], start: at(1, 0), end: at(2, 1), expected: 6),
            LengthExample(name: "an unknown count after the end does not matter", positionCounts: [4, 2, nil], start: at(0, 0), end: at(2, 0), expected: 6),
            LengthExample(name: "an unknown count in between", positionCounts: [4, nil, 4], start: at(0, 0), end: at(2, 0), expected: nil),
            LengthExample(name: "no end", start: at(0, 0), end: nil, expected: nil),
        ])
        func lengthIsCountedInPositions(_ example: LengthExample) {
            #expect(resolver(example.positionCounts).length(from: example.start, to: example.end) == example.expected.map { .positions($0) })
        }

        private static func at(_ index: Int, _ progression: Double) -> TimelinePosition {
            TimelinePosition(readingOrderIndex: index, offset: progression)
        }
    }
}

// MARK: - Helpers

private func resolver(_ positionCounts: [Int?] = [4, 2, 4]) -> WebTimelinePositionResolver {
    let readingOrder = ["a", "b", "c"].map { Link(href: $0, mediaType: .xhtml) }
    return WebTimelinePositionResolver(
        readingOrder: readingOrder,
        positionCounts: positionCounts,
        nodes: readingOrder.map { Timeline.Node(title: .text($0.href), link: Link(href: $0.href)) }
    )
}

private func locator(_ href: String, _ locations: Locator.Locations) -> Locator {
    Locator(href: AnyURL(string: href)!, mediaType: .xhtml, locations: locations)
}
