//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) @testable import ReadiumShared
import Testing
@_spi(ExperimentalTimeline) import TestSupport

enum AudioTimelineServiceTests {
    struct TableOfContents {
        @Test func entriesMirrorTheTableOfContents() async throws {
            let toc = [
                Link(href: "t1.mp3", title: "Intro"),
                Link(href: "t2.mp3#t=10", title: "Chapter", children: [
                    Link(href: "t2.mp3#t=20", title: "Section"),
                ]),
            ]

            let timeline = try await timeline(toc: toc)

            // `t3.mp3` has no entry.
            #expect(timeline.outline == [
                "0 Intro → t1.mp3",
                "1 Chapter → t2.mp3#t=10",
                "  2 Section → t2.mp3#t=20",
            ])
            #expect(timeline.toc.entries.map(\.link) == toc)
        }

        struct TableOfContentsOutline: Sendable, CustomTestStringConvertible {
            let name: String
            let toc: [Link]
            let expected: [String]

            var testDescription: String {
                name
            }
        }

        @Test(arguments: [
            TableOfContentsOutline(
                name: "untitled entries are replaced by their children",
                toc: [
                    Link(href: "t1.mp3", children: [
                        Link(href: "t1.mp3#t=5", title: "One"),
                        Link(href: "t2.mp3", title: " ", children: [Link(href: "t2.mp3#t=5", title: "Two")]),
                    ]),
                    Link(href: "t3.mp3", title: "Three"),
                ],
                expected: ["0 One → t1.mp3#t=5", "1 Two → t2.mp3#t=5", "2 Three → t3.mp3"]
            ),
            TableOfContentsOutline(
                name: "only untitled, childless entries give an empty table of contents",
                toc: [Link(href: "t1.mp3"), Link(href: "t2.mp3", title: " ")],
                expected: []
            ),
        ])
        func untitledEntriesAreReplacedByTheirChildren(_ example: TableOfContentsOutline) async throws {
            let timeline = try await timeline(toc: example.toc)

            #expect(timeline.outline == example.expected)
        }

        /// Without a table of contents, no entry is generated from the
        /// tracks, even when they are titled: the segments are the tracks.
        @Test(arguments: [false, true])
        func emptyOrFailingTableOfContentsGivesATimelineWithoutEntries(fails: Bool) async throws {
            let timeline = try await timeline(
                toc: [],
                tocService: fails ? { _ in StubTableOfContentsService(.failure(.decoding("Broken"))) } : nil
            )

            #expect(timeline.toc.isEmpty)
            #expect(timeline.segments().map(\.link) == readingOrder)
        }

        @Test func customServiceIsUsed() async throws {
            let timeline = try await timeline(
                toc: [Link(href: "t1.mp3", title: "Manifest")],
                tocService: { _ in StubTableOfContentsService(.success([Link(href: "t2.mp3", title: "Custom")])) }
            )

            #expect(timeline.outline == ["0 Custom → t2.mp3"])
        }
    }

    struct Caching {
        @Test func tableOfContentsFailureIsNotRetried() async throws {
            let service = StubTableOfContentsService(.failure(.decoding("Broken")))
            let publication = makePublication(tocService: { _ in service })

            _ = try await publication.timeline()
            _ = try await publication.timeline()

            #expect(service.callCount == 1)
            withExtendedLifetime(publication) {}
        }

        @Test func successIsCached() async throws {
            let service = StubTableOfContentsService(.success([Link(href: "t1.mp3", title: "Intro")]))
            let publication = makePublication(tocService: { _ in service })

            let first = try await publication.timeline()?.toc.entries
            let second = try await publication.timeline()?.toc.entries

            #expect(first?.isEmpty == false)
            #expect(first == second)
            #expect(service.callCount == 1)
            withExtendedLifetime(publication) {}
        }
    }

    struct PublicationHelper {
        @Test func returnsNilWithoutAService() async throws {
            let publication = Publication(manifest: Manifest(metadata: Metadata(title: ""), readingOrder: readingOrder))

            #expect(try await publication.timeline() == nil)
        }
    }

    struct Lifetime {
        @Test func failsOnceThePublicationIsDeallocated() async {
            let service = AudioTimelineService(publication: Weak())

            let error = await #expect(throws: ReadError.self) {
                _ = try await service.timeline()
            }
            guard case .unsupportedOperation? = error else {
                Issue.record("Expected an unsupportedOperation error, got \(String(describing: error))")
                return
            }
        }
    }
}

// MARK: - Helpers

/// Three tracks of 600 s, only the first one titled.
private let readingOrder = [
    Link(href: "t1.mp3", mediaType: .mp3, title: "One", duration: 600),
    Link(href: "t2.mp3", mediaType: .mp3, duration: 600),
    Link(href: "t3.mp3", mediaType: .mp3, title: " ", duration: 600),
]

private func makePublication(
    toc: [Link] = [],
    tocService: TableOfContentsServiceFactory? = nil
) -> Publication {
    Publication(
        manifest: Manifest(metadata: Metadata(title: ""), readingOrder: readingOrder, tableOfContents: toc),
        servicesBuilder: PublicationServicesBuilder(setup: {
            $0.setTimelineServiceFactory(AudioTimelineService.makeFactory())
            if let tocService {
                $0.setTableOfContentsServiceFactory(tocService)
            }
        })
    )
}

private func timeline(
    toc: [Link],
    tocService: TableOfContentsServiceFactory? = nil
) async throws -> Timeline {
    let publication = makePublication(toc: toc, tocService: tocService)
    let timeline = try #require(await publication.timeline())
    withExtendedLifetime(publication) {}
    return timeline
}

/// Answers with `toc` and counts the calls.
private final class StubTableOfContentsService: TableOfContentsService, @unchecked Sendable {
    private let toc: ReadResult<[Link]>
    private let lock = NSLock()
    private var calls = 0

    init(_ toc: ReadResult<[Link]>) {
        self.toc = toc
    }

    var callCount: Int {
        lock.withLock { calls }
    }

    func tableOfContents() async -> ReadResult<[Link]> {
        lock.withLock { calls += 1 }
        return toc
    }
}
