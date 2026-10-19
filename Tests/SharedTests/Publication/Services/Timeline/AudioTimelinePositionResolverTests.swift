//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) @testable import ReadiumShared
import Testing

/// Reading order: tracks `t1` of 600 s, `t2` of 300 s and `t3` of 900 s,
/// unless a test gives other durations.
enum AudioTimelinePositionResolverTests {
    struct Links {
        struct LinkOffset: Sendable, CustomTestStringConvertible {
            let href: String
            var readingOrderIndex = 1
            let offset: TimelineOffset

            var testDescription: String {
                href
            }
        }

        @Test(arguments: [
            LinkOffset(href: "t2#t=60", offset: .seconds(60)),
            LinkOffset(href: "t2", offset: .seconds(0)),
            LinkOffset(href: "t2#t=10,20", offset: .seconds(10)),
            // Past the known duration of the track, the offset is not clamped.
            LinkOffset(href: "t3#t=1000", readingOrderIndex: 2, offset: .seconds(1000)),
        ])
        func linkIsTurnedIntoAnOffset(_ example: LinkOffset) throws {
            let position = try #require(resolver().position(of: Link(href: example.href)))

            #expect(position.readingOrderIndex == example.readingOrderIndex)
            #expect(position.offset == example.offset)
        }

        @Test func linkOutsideTheReadingOrderHasNoPosition() {
            #expect(resolver().position(of: Link(href: "outside.mp3#t=60")) == nil)
        }
    }

    /// All the locators are in `t2`.
    struct Locators {
        struct LocatorOffset: Sendable, CustomTestStringConvertible {
            let name: String
            var durations: [TimeInterval?] = [600, 300, 900]
            let locations: Locator.Locations
            let offset: TimelineOffset

            var testDescription: String {
                name
            }
        }

        @Test(arguments: [
            LocatorOffset(
                name: "a `t=` fragment wins over the progression",
                locations: .init(fragments: ["t=60"], progression: 0.5),
                offset: .seconds(60)
            ),
            LocatorOffset(
                name: "a `t=` fragment with no duration known",
                durations: [nil, nil, nil],
                locations: .init(fragments: ["t=60"]),
                offset: .seconds(60)
            ),
            LocatorOffset(
                name: "a progression with a known duration",
                locations: .init(progression: 0.5),
                offset: .seconds(150)
            ),
            LocatorOffset(
                name: "a progression is ignored when the duration is unknown",
                durations: [600, nil, 900],
                locations: .init(progression: 0.5),
                offset: .seconds(0)
            ),
            LocatorOffset(
                name: "a progression is ignored when the duration is 0",
                durations: [600, 0, 900],
                locations: .init(progression: 0.5),
                offset: .seconds(0)
            ),
            LocatorOffset(
                name: "no location is the start of the track",
                locations: .init(),
                offset: .seconds(0)
            ),
        ])
        func locatorIsTurnedIntoAnOffset(_ example: LocatorOffset) throws {
            let locator = Locator(href: AnyURL(string: "t2")!, mediaType: .mp3, locations: example.locations)
            let position = try #require(resolver(example.durations).position(of: locator))

            #expect(position.readingOrderIndex == 1)
            #expect(position.offset == example.offset)
        }

        @Test func locatorOutsideTheReadingOrderHasNoPosition() {
            let locator = Locator(href: AnyURL(string: "outside.mp3")!, mediaType: .mp3, locations: .init(fragments: ["t=60"]))

            #expect(resolver().position(of: locator) == nil)
        }
    }
}

// MARK: - Helpers

private func resolver(_ durations: [TimeInterval?] = [600, 300, 900]) -> AudioTimelinePositionResolver {
    AudioTimelinePositionResolver(
        readingOrder: durations.enumerated().map { index, duration in
            Link(href: "t\(index + 1)", mediaType: .mp3, duration: duration)
        }
    )
}
