//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) import ReadiumShared

/// Timeline service for audio publications, built from the table of contents
/// of the publication and the durations of its reading order.
@_spi(ExperimentalTimeline)
public final class AudioTimelineService: TimelineService {
    /// - Parameter generatesFromReadingOrder: When the table of contents is
    ///   empty, generates one item per reading order resource. Otherwise, the
    ///   timeline is empty.
    public static func makeFactory(generatesFromReadingOrder: Bool) -> TimelineServiceFactory {
        { context in
            AudioTimelineService(
                publication: context.publication,
                generatesFromReadingOrder: generatesFromReadingOrder
            )
        }
    }

    private let cache: AsyncThrowingMemoizer<Timeline, ReadError>

    init(publication: Weak<Publication>, generatesFromReadingOrder: Bool) {
        cache = AsyncThrowingMemoizer { () async throws(ReadError) -> Timeline in
            guard let publication = publication() else {
                throw .unsupportedOperation(DebugError("The publication is no longer available"))
            }

            var nodes = try await publication.tableOfContents().get().timelineNodes
            if nodes.isEmpty, generatesFromReadingOrder {
                nodes = publication.readingOrder.enumerated().map { index, link in
                    Timeline.Node(
                        title: link.title?.orNilIfBlank().map { .text($0) } ?? .number(index + 1),
                        link: link
                    )
                }
            }

            return Timeline(nodes: nodes, resolver: AudioTimelinePositionResolver(readingOrder: publication.readingOrder))
        }
    }

    /// Builds the timeline once. A failure is not cached, so the next call
    /// tries again.
    public func timeline() async throws(ReadError) -> Timeline {
        try await cache()
    }
}

private extension [Link] {
    /// Nodes of the timeline of this table of contents.
    var timelineNodes: [Timeline.Node] {
        flatMap { link -> [Timeline.Node] in
            let children = link.children.timelineNodes
            guard let title = link.title?.orNilIfBlank() else {
                return children
            }
            return [Timeline.Node(title: .text(title), link: link, children: children)]
        }
    }
}
