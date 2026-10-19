//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) @testable import ReadiumShared
import Testing

/// Reading order: `a.pdf` of 10 pages and `b.pdf` of 5 pages, unless a test
/// gives other page counts.
enum PDFTimelinePositionResolverTests {
    struct Links {
        struct LinkPage: Sendable, CustomTestStringConvertible {
            let href: String
            var pageCounts: [Int?] = [10, 5]
            var readingOrderIndex = 1
            let offset: TimelineOffset

            var testDescription: String {
                "\(href) with \(pageCounts)"
            }
        }

        @Test(arguments: [
            LinkPage(href: "a.pdf#page=3", readingOrderIndex: 0, offset: .page(2)),
            LinkPage(href: "b.pdf", offset: .page(0)),
            LinkPage(href: "b.pdf#page=0", offset: .page(0)),
            LinkPage(href: "b.pdf#page=9", offset: .page(4)),
            LinkPage(href: "b.pdf#page=9", pageCounts: [10, nil], offset: .page(8)),
        ])
        func linkIsTurnedIntoAPage(_ example: LinkPage) throws {
            let position = try #require(resolver(example.pageCounts).position(of: Link(href: example.href)))

            #expect(position.readingOrderIndex == example.readingOrderIndex)
            #expect(position.offset == example.offset)
        }

        @Test func linkOutsideTheReadingOrderHasNoPosition() {
            #expect(resolver([10, 5]).position(of: Link(href: "outside.pdf#page=1")) == nil)
        }
    }

    /// All the locators are in `b.pdf`, at positions 11 to 15.
    struct Locators {
        struct LocatorPage: Sendable, CustomTestStringConvertible {
            let name: String
            var pageCounts: [Int?] = [10, 5]
            let locations: Locator.Locations
            let offset: TimelineOffset

            var testDescription: String {
                name
            }
        }

        @Test(arguments: [
            LocatorPage(
                name: "a `page=` fragment wins over the position and the progression",
                locations: .init(fragments: ["page=3"], progression: 0.8, position: 12),
                offset: .page(2)
            ),
            LocatorPage(
                name: "a `page=` fragment past the last page is clamped",
                locations: .init(fragments: ["page=9"]),
                offset: .page(4)
            ),
            LocatorPage(
                name: "an invalid `page=` fragment is ignored",
                locations: .init(fragments: ["page=0"], position: 13),
                offset: .page(2)
            ),
            LocatorPage(
                name: "the first position of the resource wins over the progression",
                locations: .init(progression: 0.8, position: 11),
                offset: .page(0)
            ),
            LocatorPage(
                name: "the last position of the resource",
                locations: .init(position: 15),
                offset: .page(4)
            ),
            LocatorPage(
                name: "a position before the resource is ignored",
                locations: .init(progression: 0.5, position: 10),
                offset: .page(2)
            ),
            LocatorPage(
                name: "a position after the resource is ignored",
                locations: .init(progression: 0.5, position: 16),
                offset: .page(2)
            ),
            LocatorPage(
                name: "a position is ignored when a preceding page count is unknown",
                pageCounts: [nil, 5],
                locations: .init(progression: 0.8, position: 2),
                offset: .page(4)
            ),
            LocatorPage(
                name: "a position is not clamped when the page count of the resource is unknown",
                pageCounts: [10, nil],
                locations: .init(position: 20),
                offset: .page(9)
            ),
            LocatorPage(
                name: "a progression is rounded down",
                locations: .init(progression: 0.5),
                offset: .page(2)
            ),
            LocatorPage(
                name: "a progression of 1 is the last page",
                locations: .init(progression: 1),
                offset: .page(4)
            ),
            LocatorPage(
                name: "a progression past 1 is the last page",
                locations: .init(progression: 1e300),
                offset: .page(4)
            ),
            LocatorPage(
                name: "a negative progression is the first page",
                locations: .init(progression: -1),
                offset: .page(0)
            ),
            LocatorPage(
                name: "a progression is ignored when the page count is unknown",
                pageCounts: [10, nil],
                locations: .init(progression: 0.5),
                offset: .page(0)
            ),
            LocatorPage(
                name: "no location is the first page",
                locations: .init(),
                offset: .page(0)
            ),
        ])
        func locatorIsTurnedIntoAPage(_ example: LocatorPage) throws {
            let locator = Locator(href: AnyURL(string: "b.pdf")!, mediaType: .pdf, locations: example.locations)
            let position = try #require(resolver(example.pageCounts).position(of: locator))

            #expect(position.readingOrderIndex == 1)
            #expect(position.offset == example.offset)
        }

        @Test func locatorOutsideTheReadingOrderHasNoPosition() {
            let locator = Locator(href: AnyURL(string: "outside.pdf")!, mediaType: .pdf, locations: .init(fragments: ["page=1"]))

            #expect(resolver([10, 5]).position(of: locator) == nil)
        }
    }
}

// MARK: - Helpers

private func resolver(_ pageCounts: [Int?]) -> PDFTimelinePositionResolver {
    PDFTimelinePositionResolver(
        readingOrder: [
            Link(href: "a.pdf", mediaType: .pdf),
            Link(href: "b.pdf", mediaType: .pdf),
        ],
        pageCounts: pageCounts
    )
}
