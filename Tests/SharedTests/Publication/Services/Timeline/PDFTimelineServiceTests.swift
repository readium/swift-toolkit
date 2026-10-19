//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) @testable import ReadiumShared
@_spi(ExperimentalTimeline) import TestSupport
import Testing

/// Reading order: `a.pdf` of 10 pages and `b.pdf` of 5 pages.
///
/// - Part 1 → `a.pdf`
///   - Chapter 1 → `a.pdf#page=3`
/// - Chapter 2 → `b.pdf#page=2`
struct PDFTimelineServiceTests {
    @Test func itemsArePlacedOnThePagesOfThePositions() async throws {
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
        #expect(segments.map(\.start.offset) == [.page(0), .page(2), .page(1)])
        #expect(segments.map { $0.end?.readingOrderIndex } == [0, 1, 1])
        #expect(segments.map { $0.end?.offset } == [.page(2), .page(1), .page(5)])
        #expect(timeline.items[1].end?.totalProgression == 1)
    }

    /// Without positions, the pages are still placed, but the end of the
    /// publication is unknown.
    @Test func pageCountsAreUnknownWithoutPositions() async throws {
        let timeline = try await timeline(positions: nil)

        #expect(timeline.items.map { $0.start?.readingOrderIndex } == [0, 1])
        #expect(timeline.items.map { $0.start?.offset } == [.page(0), .page(1)])
        #expect(timeline.items[1].end == nil)
    }

    /// Unlike for an audiobook, no items are generated from the reading order.
    @Test func emptyTableOfContentsGivesAnEmptyTimeline() async throws {
        let timeline = try await timeline(toc: [], positions: nil)

        #expect(timeline.items.isEmpty)
    }

    @Test func positionsFailureIsThrownAndNotCached() async throws {
        let service = FailingOncePositionsService(positions: positions([10, 5]))
        let publication = makePublication(positions: { _ in service })

        let error = await #expect(throws: ReadError.self) {
            _ = try await publication.timeline()
        }
        guard case .decoding? = error else {
            Issue.record("Expected a decoding error, got \(String(describing: error))")
            return
        }
        #expect(try await publication.timeline()?.items[1].end?.offset == .page(5))
        withExtendedLifetime(publication) {}
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

private func makePublication(toc: [Link]? = nil, positions: PositionsServiceFactory?) -> Publication {
    Publication(
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
            if let positions {
                $0.setPositionsServiceFactory(positions)
            }
        })
    )
}

private func timeline(toc: [Link]? = nil, positions: PositionsServiceFactory?) async throws -> Timeline {
    let publication = makePublication(toc: toc, positions: positions)
    let timeline = try #require(await publication.timeline())
    withExtendedLifetime(publication) {}
    return timeline
}

/// One position per page of each resource.
private func positions(_ pageCounts: [Int]) -> [[Locator]] {
    pageCounts.enumerated().map { index, pageCount in
        (0 ..< pageCount).map { _ in
            Locator(href: AnyURL(string: index == 0 ? "a.pdf" : "b.pdf")!, mediaType: .pdf)
        }
    }
}

/// Fails on the first call only.
private final class FailingOncePositionsService: PositionsService, @unchecked Sendable {
    private let positions: [[Locator]]
    private let lock = NSLock()
    private var calls = 0

    init(positions: [[Locator]]) {
        self.positions = positions
    }

    func positionsByReadingOrder() async -> ReadResult<[[Locator]]> {
        let call = lock.withLock {
            calls += 1
            return calls
        }
        return call == 1 ? .failure(.decoding("Broken")) : .success(positions)
    }
}
