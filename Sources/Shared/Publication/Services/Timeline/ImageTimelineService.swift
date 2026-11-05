//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Timeline service for publications of bitmap images, such as a comic,
/// built from the table of contents of the publication, with one page for
/// each image of its reading order.
@_spi(ExperimentalTimeline)
public final class ImageTimelineService: TimelineService {
    public static func makeFactory() -> TimelineServiceFactory {
        { context in
            ImageTimelineService(publication: context.publication)
        }
    }

    private let cache: AsyncThrowingMemoizer<Timeline, ReadError>

    init(publication: Weak<Publication>) {
        cache = AsyncThrowingMemoizer { () async throws(ReadError) -> Timeline in
            guard let publication = publication() else {
                throw .unsupportedOperation(DebugError("The publication is no longer available"))
            }

            let nodes = try await publication.tableOfContents().get().timelineNodes
            return Timeline(
                nodes: nodes,
                resolver: ImageTimelinePositionResolver(readingOrder: publication.readingOrder)
            )
        }
    }

    /// Builds the timeline once. A failure is not cached, so the next call
    /// tries again.
    public func timeline() async throws(ReadError) -> Timeline {
        try await cache()
    }
}
