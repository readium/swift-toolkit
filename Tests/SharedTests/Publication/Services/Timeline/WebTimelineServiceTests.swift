//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) @testable import ReadiumShared
@_spi(ExperimentalTimeline) import TestSupport
import Testing

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

        #expect(timeline.items.map(\.start) == [position(1), nil, position(3), nil, position(4), nil])
        #expect(timeline.items.map(\.end) == [position(3), nil, position(4), nil, position(4, 1), nil])
    }

    struct ResourceChapter: Sendable, CustomTestStringConvertible {
        let name: String
        let href: String
        let progression: Double
        /// Title of the located item, `nil` for none.
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

        #expect(timeline.locate(locator)?.title == example.expected.map { .text($0) })
    }

    @Test func aSplitChapterCoversItsFollowingResources() async throws {
        let timeline = try await timeline()

        #expect(timeline.segments(in: AnyURL(string: "ch1b.xhtml")!) == [
            TimelineSegment(item: timeline.items[0], start: position(2), end: position(2, 1)),
        ])
    }

    @Test func nextAndPreviousSkipTheUnplacedEntries() async throws {
        let timeline = try await timeline()
        let chapter1 = timeline.items[0]
        let chapter2 = timeline.items[2]
        let chapter3 = timeline.items[4]

        #expect(timeline.next(after: chapter1) == chapter2)
        #expect(timeline.next(after: chapter2) == chapter3)
        #expect(timeline.previous(before: chapter3) == chapter2)
        #expect(timeline.previous(before: chapter2) == chapter1)
    }

    /// A fixed-layout locator usually has no progression.
    @Test func fixedLayoutResourcesAreLikeReflowableOnes() async throws {
        let timeline = try await timeline(layout: .fixed)
        let locator = Locator(href: AnyURL(string: "ch1a.xhtml")!, mediaType: .xhtml)

        #expect(timeline.items[0].start == position(1))
        #expect(timeline.locate(locator) == timeline.items[0])
    }

    @Test func readsTheTableOfContentsService() async throws {
        let timeline = try await timeline(tocService: { _ in
            StubTableOfContentsService(toc: [Link(href: "ch2.xhtml", title: "Custom")])
        })

        #expect(timeline.outline == ["0 Custom → ch2.xhtml"])
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
    tocService: TableOfContentsServiceFactory? = nil
) async throws -> Timeline {
    let publication = Publication(
        manifest: Manifest(
            metadata: Metadata(title: "", layout: layout),
            readingOrder: ["cover", "ch1a", "ch1b", "ch2", "ch3"].map {
                Link(href: "\($0).xhtml", mediaType: .xhtml)
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
        })
    )
    let timeline = try #require(await publication.timeline())
    withExtendedLifetime(publication) {}
    return timeline
}

private func position(_ index: Int, _ progression: Double = 0) -> TimelinePosition {
    TimelinePosition(readingOrderIndex: index, offset: .scroll(progression))
}

private struct StubTableOfContentsService: TableOfContentsService {
    let toc: [Link]

    func tableOfContents() async -> ReadResult<[Link]> {
        .success(toc)
    }
}
