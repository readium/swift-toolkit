//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) @testable import ReadiumShared
import Testing
@_spi(ExperimentalTimeline) import TestSupport

/// Reading order: `a.jpg`, `b.jpg` and `c.jpg`.
///
/// - Chapter 1 → `a.jpg`
/// - Chapter 2 → `c.jpg`
struct ImageTimelineServiceTests {
    @Test func eachImageIsAPage() async throws {
        let publication = makePublication()
        let timeline = try #require(await publication.timeline())

        #expect(timeline.toc.entries.map { $0.start?.coordinate } == [.page(1), .page(3)])
        #expect(timeline.toc.entries.map(\.length) == [.pages(2), .pages(1)])
        #expect(timeline.toc.entries[1].end?.coordinate == .page(4))

        let locator = Locator(href: AnyURL(string: "b.jpg")!, mediaType: .jpeg, locations: .init(progression: 0.5))
        #expect(timeline.position(of: locator) == TimelinePosition(
            readingOrderIndex: 1,
            offset: 0,
            coordinate: .page(2),
            progression: 0,
            totalProgression: 1 / 3
        ))
        #expect(timeline.segments().segment(containing: locator)?.tocEntry == timeline.toc.entries[0])
    }

    /// The pages match the positions list of the publication.
    @Test func pagesAreThePositionsOfThePublication() async throws {
        let publication = makePublication()
        let timeline = try #require(await publication.timeline())

        let positions = try await publication.positions().get()
        #expect(positions.count == 3)
        for locator in positions {
            #expect(timeline.position(of: locator)?.coordinate == locator.locations.position.map { .page($0) })
        }
    }

    @Test func tableOfContentsFailureGivesATimelineWithoutEntries() async throws {
        let publication = makePublication(tocService: { _ in StubTableOfContentsService.failing() })
        let timeline = try #require(await publication.timeline())

        #expect(timeline.toc.isEmpty)
        #expect(timeline.segments().map(\.link.href) == ["a.jpg", "b.jpg", "c.jpg"])
    }

    @Test func failsOnceThePublicationIsDeallocated() async {
        let service = ImageTimelineService(publication: Weak())

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

private func makePublication(tocService: TableOfContentsServiceFactory? = nil) -> Publication {
    Publication(
        manifest: Manifest(
            metadata: Metadata(title: ""),
            readingOrder: ["a.jpg", "b.jpg", "c.jpg"].map { Link(href: $0, mediaType: .jpeg) },
            tableOfContents: [
                Link(href: "a.jpg", title: "Chapter 1"),
                Link(href: "c.jpg", title: "Chapter 2"),
            ]
        ),
        servicesBuilder: PublicationServicesBuilder(setup: {
            $0.setPositionsServiceFactory(PerResourcePositionsService.makeFactory(fallbackMediaType: .jpeg))
            $0.setTimelineServiceFactory(ImageTimelineService.makeFactory())
            if let tocService {
                $0.setTableOfContentsServiceFactory(tocService)
            }
        })
    )
}
