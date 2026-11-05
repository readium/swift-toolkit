//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) @testable import ReadiumShared
import Testing
@_spi(ExperimentalTimeline) import TestSupport

/// Reading order: `a.pdf` of 10 pages and `b.pdf` of 5 pages.
///
/// - Part 1 → `a.pdf`
///   - Chapter 1 → `a.pdf#page=3`
/// - Chapter 2 → `b.pdf#page=2`
struct PDFTimelineServiceTests {
    @Test func entriesArePlacedOnThePagesOfThePositions() async throws {
        let timeline = try await timeline(positions: { _ in
            InMemoryPositionsService(positionsByReadingOrder: positions([10, 5]))
        })

        #expect(timeline.outline == [
            "0 Part 1 → a.pdf",
            "  1 Chapter 1 → a.pdf#page=3",
            "2 Chapter 2 → b.pdf#page=2",
        ])
        let segments = timeline.segments()
        #expect(segments.map(\.start.readingOrderIndex) == [0, 0, 1])
        #expect(segments.map(\.start.offset) == [0, 2, 1])
        #expect(segments.map { $0.end?.readingOrderIndex } == [0, 1, 1])
        #expect(segments.map { $0.end?.offset } == [2, 1, 5])
        #expect(timeline.toc.entries[1].end?.totalProgression == 1)
        #expect(timeline.toc.entries.map(\.length) == [.pages(11), .pages(4)])
    }

    /// The pages match the positions list of the publication.
    @Test func pagesAreThePositionsOfThePublication() async throws {
        let positionsByReadingOrder = positions([10, 5])
        let timeline = try await timeline(positions: { _ in
            InMemoryPositionsService(positionsByReadingOrder: positionsByReadingOrder)
        })

        for locator in positionsByReadingOrder.flatMap(\.self) {
            #expect(timeline.position(of: locator)?.coordinate == locator.locations.position.map { .page($0) })
        }
    }

    /// Without positions, the pages are still placed, but the end of the
    /// publication and the lengths are unknown.
    @Test(arguments: [nil, FailingPositionsService()])
    func pageCountsAreUnknownWithoutPositions(_ service: FailingPositionsService?) async throws {
        let timeline = try await timeline(positions: service.map { service in { _ in service } })

        #expect(timeline.toc.entries.map { $0.start?.readingOrderIndex } == [0, 1])
        #expect(timeline.toc.entries.map { $0.start?.offset } == [0, 1])
        #expect(timeline.toc.entries[1].end == nil)
        #expect(timeline.toc.entries.map(\.length) == [nil, nil])
    }

    /// Unlike for an audiobook, no entries are generated from the reading order.
    @Test func emptyTableOfContentsGivesAnEmptyTimeline() async throws {
        let timeline = try await timeline(toc: [], positions: nil)

        #expect(timeline.toc.isEmpty)
    }

    @Test func tableOfContentsFailureGivesATimelineWithoutEntries() async throws {
        let timeline = try await timeline(tocService: { _ in FailingTableOfContentsService() }, positions: nil)

        #expect(timeline.toc.isEmpty)
        #expect(timeline.segments().map(\.link.href) == ["a.pdf", "b.pdf"])
    }

    @Test func failsOnceThePublicationIsDeallocated() async {
        let service = PDFTimelineService(publication: Weak())

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
    toc: [Link]? = nil,
    tocService: TableOfContentsServiceFactory? = nil,
    positions: PositionsServiceFactory?
) async throws -> Timeline {
    let publication = Publication(
        manifest: Manifest(
            metadata: Metadata(title: ""),
            readingOrder: [
                Link(href: "a.pdf", mediaType: .pdf),
                Link(href: "b.pdf", mediaType: .pdf),
            ],
            tableOfContents: toc ?? [
                Link(href: "a.pdf", title: "Part 1", children: [
                    Link(href: "a.pdf#page=3", title: "Chapter 1"),
                ]),
                Link(href: "b.pdf#page=2", title: "Chapter 2"),
            ]
        ),
        servicesBuilder: PublicationServicesBuilder(setup: {
            $0.setTimelineServiceFactory(PDFTimelineService.makeFactory())
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

/// One position per page of each resource, numbered across the resources.
private func positions(_ pageCounts: [Int]) -> [[Locator]] {
    pageCounts.enumerated().map { index, pageCount in
        let previousPageCount = pageCounts[..<index].reduce(0, +)
        return (1 ... pageCount).map { page in
            Locator(
                href: AnyURL(string: index == 0 ? "a.pdf" : "b.pdf")!,
                mediaType: .pdf,
                locations: .init(fragments: ["page=\(page)"], position: previousPageCount + page)
            )
        }
    }
}
