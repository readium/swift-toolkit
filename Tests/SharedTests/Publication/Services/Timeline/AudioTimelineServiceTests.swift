//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) @testable import ReadiumShared
@_spi(ExperimentalTimeline) import TestSupport
import Testing

enum AudioTimelineServiceTests {
    struct TableOfContents {
        @Test func itemsMirrorTheTableOfContents() async throws {
            let toc = [
                Link(href: "t1.mp3", title: "Intro"),
                Link(href: "t2.mp3#t=10", title: "Chapter", children: [
                    Link(href: "t2.mp3#t=20", title: "Section"),
                ]),
            ]

            let timeline = try await timeline(toc: toc)

            // `t3.mp3` gets no generated item.
            #expect(timeline.outline == [
                "0 Intro → t1.mp3",
                "1 Chapter → t2.mp3#t=10",
                "  2 Section → t2.mp3#t=20",
            ])
            #expect(timeline.items.map(\.link) == toc)
        }

        struct TableOfContentsOutline: Sendable, CustomTestStringConvertible {
            let name: String
            let toc: [Link]
            var generatesFromReadingOrder = true
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
                name: "an empty table of contents generates one item per track",
                toc: [],
                expected: ["0 One → t1.mp3", "1 #2 → t2.mp3", "2 #3 → t3.mp3"]
            ),
            TableOfContentsOutline(
                name: "only untitled, childless entries count as an empty table of contents",
                toc: [Link(href: "t1.mp3"), Link(href: "t2.mp3", title: " ")],
                expected: ["0 One → t1.mp3", "1 #2 → t2.mp3", "2 #3 → t3.mp3"]
            ),
            TableOfContentsOutline(
                name: "an empty table of contents gives an empty timeline with the option off",
                toc: [],
                generatesFromReadingOrder: false,
                expected: []
            ),
        ])
        func untitledOrMissingEntries(_ example: TableOfContentsOutline) async throws {
            let timeline = try await timeline(toc: example.toc, generatesFromReadingOrder: example.generatesFromReadingOrder)

            #expect(timeline.outline == example.expected)
        }

        @Test func generatedItemsLinkToTheStartOfEachTrack() async throws {
            let timeline = try await timeline(toc: [])

            #expect(timeline.items.map(\.link) == readingOrder)
            #expect(timeline.items.map { $0.start?.readingOrderIndex } == [0, 1, 2])
            #expect(timeline.items.map { $0.start?.offset } == [.seconds(0), .seconds(0), .seconds(0)])
        }

        @Test func customServiceIsUsed() async throws {
            let timeline = try await timeline(
                toc: [Link(href: "t1.mp3", title: "Manifest")],
                tocService: { _ in StubTableOfContentsService { _ in .success([Link(href: "t2.mp3", title: "Custom")]) } }
            )

            #expect(timeline.outline == ["0 Custom → t2.mp3"])
        }
    }

    struct Caching {
        @Test func failureIsThrownAndNotCached() async throws {
            let service = StubTableOfContentsService { call in
                call == 1 ? .failure(.decoding("Broken")) : .success([Link(href: "t1.mp3", title: "Intro")])
            }
            let publication = makePublication(tocService: { _ in service })

            let error = await #expect(throws: ReadError.self) {
                _ = try await publication.timeline()
            }
            if case .decoding? = error {} else {
                Issue.record("Expected a decoding error, got \(String(describing: error))")
            }
            #expect(try await publication.timeline()?.outline == ["0 Intro → t1.mp3"])
            withExtendedLifetime(publication) {}
        }

        @Test func successIsCached() async throws {
            let service = StubTableOfContentsService { _ in .success([Link(href: "t1.mp3", title: "Intro")]) }
            let publication = makePublication(tocService: { _ in service })

            let first = try await publication.timeline()?.items
            let second = try await publication.timeline()?.items

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
            let service = AudioTimelineService(publication: Weak(), generatesFromReadingOrder: true)

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
    generatesFromReadingOrder: Bool = true,
    tocService: TableOfContentsServiceFactory? = nil
) -> Publication {
    Publication(
        manifest: Manifest(metadata: Metadata(title: ""), readingOrder: readingOrder, tableOfContents: toc),
        servicesBuilder: PublicationServicesBuilder(setup: {
            $0.setTimelineServiceFactory(AudioTimelineService.makeFactory(generatesFromReadingOrder: generatesFromReadingOrder))
            if let tocService {
                $0.setTableOfContentsServiceFactory(tocService)
            }
        })
    )
}

private func timeline(
    toc: [Link],
    generatesFromReadingOrder: Bool = true,
    tocService: TableOfContentsServiceFactory? = nil
) async throws -> Timeline {
    let publication = makePublication(toc: toc, generatesFromReadingOrder: generatesFromReadingOrder, tocService: tocService)
    let timeline = try #require(await publication.timeline())
    withExtendedLifetime(publication) {}
    return timeline
}

/// Answers with `toc`, which takes the number of the call, starting at 1.
private final class StubTableOfContentsService: TableOfContentsService, @unchecked Sendable {
    private let toc: @Sendable (_ call: Int) -> ReadResult<[Link]>
    private let lock = NSLock()
    private var calls = 0

    init(_ toc: @escaping @Sendable (_ call: Int) -> ReadResult<[Link]>) {
        self.toc = toc
    }

    var callCount: Int {
        lock.withLock { calls }
    }

    func tableOfContents() async -> ReadResult<[Link]> {
        let call = lock.withLock {
            calls += 1
            return calls
        }
        return toc(call)
    }
}
