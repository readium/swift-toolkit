//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Timeline service for audio publications, built from the table of contents
/// of the publication and the durations of its reading order.
@_spi(ExperimentalTimeline)
public final class AudioTimelineService: TimelineService {
    /// - Parameter generatesFromReadingOrder: When the table of contents is
    ///   empty or fails to load, generates one entry per reading order
    ///   resource. Otherwise, the timeline is empty.
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

            var nodes = await publication.timelineNodes()
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

    /// Builds the timeline once, with an empty table of contents when it fails
    /// to load.
    public func timeline() async throws(ReadError) -> Timeline {
        try await cache()
    }
}
