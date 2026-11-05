//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) @testable import ReadiumShared
import Testing
@_spi(ExperimentalTimeline) import TestSupport

/// Reading order: `cover`, `ch1a`, `ch1b`, `ch2` and `ch3`, where Chapter 1 is
/// split across `ch1a` and `ch1b`.
///
/// - (untitled) → `ch1a`
///   - Chapter 1 → `ch1a#start`
///   - Section 1.1 → `ch1a#s11` (same resource as Chapter 1)
/// - Chapter 2 → `ch2#top`
/// - Notes 1 → `ch1b` (goes back)
/// - Chapter 3 → `ch3`
/// - Appendix → `outside` (not in the reading order)
///
/// The publication has no positions, unless a test gives some.
struct WebTimelineServiceTests {
    @Test func untitledEntriesAreReplacedByTheirChildren() async throws {
        let timeline = try await timeline()

        #expect(timeline.outline == [
            "0 Chapter 1 → ch1a.xhtml#start",
            "1 Section 1.1 → ch1a.xhtml#s11",
            "2 Chapter 2 → ch2.xhtml#top",
            "3 Notes 1 → ch1b.xhtml",
            "4 Chapter 3 → ch3.xhtml",
            "5 Appendix → outside.xhtml",
        ])
    }

    /// Notes 1 is the first entry of `ch1b`, but goes back. Chapter 3 ends
    /// with the publication.
    @Test func onlyTheFirstEntryOfEachResourceIsPlaced() async throws {
        let timeline = try await timeline()

        #expect(timeline.toc.entries.map(\.start) == [position(1), nil, position(3), nil, position(4), nil])
        #expect(timeline.toc.entries.map(\.end) == [position(3), nil, position(4), nil, position(4, 1), nil])
    }

    /// `cover`, `ch1a`, `ch1b`, `ch2` and `ch3` have 1, 3, 2, 4 and 5
    /// positions.
    @Test func entriesAreMeasuredInPositions() async throws {
        let timeline = try await timeline(positions: { _ in
            InMemoryPositionsService(positionsByReadingOrder: positions([1, 3, 2, 4, 5]))
        })

        #expect(timeline.toc.entries.map { $0.start?.coordinate } == [.position(2), nil, .position(7), nil, .position(11), nil])
        #expect(timeline.toc.entries.map(\.length) == [.positions(5), nil, .positions(4), nil, .positions(5), nil])
        #expect(timeline.toc.entries[4].end?.coordinate == .position(16))
        #expect(timeline.toc.entries[4].end?.totalProgression == 1)
    }

    /// The positions of a fixed-layout publication are pages.
    @Test func fixedLayoutEntriesAreMeasuredInPages() async throws {
        let timeline = try await timeline(layout: .fixed, positions: { _ in
            InMemoryPositionsService(positionsByReadingOrder: positions([1, 3, 2, 4, 5]))
        })

        #expect(timeline.toc.entries.map { $0.start?.coordinate } == [.page(2), nil, .page(7), nil, .page(11), nil])
        #expect(timeline.toc.entries.map(\.length) == [.pages(5), nil, .pages(4), nil, .pages(5), nil])
    }

    /// A reflowable resource has several positions, which are not pages.
    @Test func fixedLayoutWithAReflowableResourceIsMeasuredInPositions() async throws {
        let timeline = try await timeline(layout: .fixed, reflowableResources: ["ch2"], positions: { _ in
            InMemoryPositionsService(positionsByReadingOrder: positions([1, 3, 2, 4, 5]))
        })

        #expect(timeline.toc.entries[0].start?.coordinate == .position(2))
        #expect(timeline.toc.entries[0].length == .positions(5))
    }

    /// Without positions, the entries are still placed.
    @Test(arguments: [nil, FailingPositionsService()])
    func entriesAreNotMeasuredWithoutPositions(_ service: FailingPositionsService?) async throws {
        let timeline = try await timeline(positions: service.map { service in { _ in service } })

        #expect(timeline.toc.entries.map(\.start) == [position(1), nil, position(3), nil, position(4), nil])
        #expect(timeline.toc.entries.map(\.length) == [nil, nil, nil, nil, nil, nil])
    }

    struct ResourceChapter: Sendable, CustomTestStringConvertible {
        let name: String
        let href: String
        let progression: Double
        /// Title of the located entry, `nil` for none.
        let expected: String?

        var testDescription: String {
            name
        }
    }

    @Test(arguments: [
        ResourceChapter(name: "the cover is before the first chapter", href: "cover.xhtml", progression: 0.5, expected: nil),
        ResourceChapter(name: "the resource of a chapter", href: "ch1a.xhtml", progression: 0.9, expected: "Chapter 1"),
        ResourceChapter(name: "the second resource of a split chapter", href: "ch1b.xhtml", progression: 0.5, expected: "Chapter 1"),
        ResourceChapter(name: "the start of a chapter with a fragment", href: "ch2.xhtml", progression: 0, expected: "Chapter 2"),
        ResourceChapter(name: "the end of the last chapter", href: "ch3.xhtml", progression: 1, expected: "Chapter 3"),
        ResourceChapter(name: "a resource outside the reading order", href: "outside.xhtml", progression: 0, expected: nil),
    ])
    func locatesTheChapterOfTheResource(_ example: ResourceChapter) async throws {
        let timeline = try await timeline()
        let locator = Locator(href: AnyURL(string: example.href)!, mediaType: .xhtml, locations: .init(progression: example.progression))

        #expect(timeline.item(containing: locator)?.title == example.expected.map { .text($0) })
    }

    @Test func aSplitChapterCoversItsFollowingResources() async throws {
        let timeline = try await timeline()

        #expect(timeline.segments().segments(in: AnyURL(string: "ch1b.xhtml")!) == [
            TimelineSegment(
                tocEntry: timeline.toc.entries[0],
                link: Link(href: "ch1b.xhtml", mediaType: .xhtml),
                start: position(2),
                end: position(2, 1)
            ),
        ])
    }

    @Test func nextAndPreviousSkipTheUnplacedEntries() async throws {
        let timeline = try await timeline()
        let chapter1 = timeline.toc.entries[0]
        let chapter2 = timeline.toc.entries[2]
        let chapter3 = timeline.toc.entries[4]

        #expect(timeline.next(after: chapter1) == chapter2)
        #expect(timeline.next(after: chapter2) == chapter3)
        #expect(timeline.previous(before: chapter3) == chapter2)
        #expect(timeline.previous(before: chapter2) == chapter1)
    }

    /// A fixed-layout locator usually has no progression.
    @Test func fixedLayoutResourcesAreLikeReflowableOnes() async throws {
        let timeline = try await timeline(layout: .fixed)
        let locator = Locator(href: AnyURL(string: "ch1a.xhtml")!, mediaType: .xhtml)

        #expect(timeline.toc.entries[0].start == position(1))
        #expect(timeline.item(containing: locator) == timeline.toc.entries[0])
    }

    @Test func readsTheTableOfContentsService() async throws {
        let timeline = try await timeline(tocService: { _ in
            StubTableOfContentsService(toc: [Link(href: "ch2.xhtml", title: "Custom")])
        })

        #expect(timeline.outline == ["0 Custom → ch2.xhtml"])
    }

    @Test func tableOfContentsFailureGivesATimelineWithoutEntries() async throws {
        let timeline = try await timeline(tocService: { _ in FailingTableOfContentsService() })

        #expect(timeline.toc.isEmpty)
        #expect(timeline.segments().map(\.link.href) == resources.map { "\($0).xhtml" })
    }

    @Test func failsOnceThePublicationIsDeallocated() async {
        let service = WebTimelineService(publication: Weak())

        let error = await #expect(throws: ReadError.self) {
            _ = try await service.timeline()
        }
        guard case .unsupportedOperation? = error else {
            Issue.record("Expected an unsupportedOperation error, got \(String(describing: error))")
            return
        }
    }
}

// MARK: - Helpers

private func timeline(
    layout: Layout? = nil,
    reflowableResources: Set<String> = [],
    tocService: TableOfContentsServiceFactory? = nil,
    positions: PositionsServiceFactory? = nil
) async throws -> Timeline {
    let publication = Publication(
        manifest: Manifest(
            metadata: Metadata(title: "", layout: layout),
            readingOrder: resources.map {
                Link(
                    href: "\($0).xhtml",
                    mediaType: .xhtml,
                    properties: reflowableResources.contains($0) ? Properties(["layout": "reflowable"]) : Properties()
                )
            },
            tableOfContents: [
                Link(href: "ch1a.xhtml", children: [
                    Link(href: "ch1a.xhtml#start", title: "Chapter 1"),
                    Link(href: "ch1a.xhtml#s11", title: "Section 1.1"),
                ]),
                Link(href: "ch2.xhtml#top", title: "Chapter 2"),
                Link(href: "ch1b.xhtml", title: "Notes 1"),
                Link(href: "ch3.xhtml", title: "Chapter 3"),
                Link(href: "outside.xhtml", title: "Appendix"),
            ]
        ),
        servicesBuilder: PublicationServicesBuilder(setup: {
            $0.setTimelineServiceFactory(WebTimelineService.makeFactory())
            if let tocService {
                $0.setTableOfContentsServiceFactory(tocService)
            }
            if let positions {
                $0.setPositionsServiceFactory(positions)
            }
        })
    )
    let timeline = try #require(await publication.timeline())
    withExtendedLifetime(publication) {}
    return timeline
}

private let resources = ["cover", "ch1a", "ch1b", "ch2", "ch3"]

/// Position without positions.
private func position(_ index: Int, _ progression: Double = 0) -> TimelinePosition {
    TimelinePosition(readingOrderIndex: index, offset: progression, progression: progression)
}

/// The given number of positions in each resource.
private func positions(_ counts: [Int]) -> [[Locator]] {
    zip(resources, counts).map { resource, count in
        (0 ..< count).map { _ in Locator(href: AnyURL(string: "\(resource).xhtml")!, mediaType: .xhtml) }
    }
}

private struct StubTableOfContentsService: TableOfContentsService {
    let toc: [Link]

    func tableOfContents() async -> ReadResult<[Link]> {
        .success(toc)
    }
}
