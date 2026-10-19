//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Timeline service for PDF publications, built from the table of contents
/// of the publication and the page count of each document in its reading
/// order.
///
/// The page counts are read from the positions of the publication, so that
/// they match the positions of the navigator.
@_spi(ExperimentalTimeline)
public final class PDFTimelineService: TimelineService {
    public static func makeFactory() -> TimelineServiceFactory {
        { context in
            PDFTimelineService(publication: context.publication)
        }
    }

    private let cache: AsyncThrowingMemoizer<Timeline, ReadError>

    init(publication: Weak<Publication>) {
        cache = AsyncThrowingMemoizer { () async throws(ReadError) -> Timeline in
            guard let publication = publication() else {
                throw .unsupportedOperation(DebugError("The publication is no longer available"))
            }

            let nodes = try await publication.tableOfContents().get().timelineNodes
            let pageCounts = try await publication.positionsByReadingOrder().get().map(\.count)
            return Timeline(
                nodes: nodes,
                resolver: PDFTimelinePositionResolver(readingOrder: publication.readingOrder, pageCounts: pageCounts)
            )
        }
    }

    /// Builds the timeline once. A failure is not cached, so the next call
    /// tries again.
    public func timeline() async throws(ReadError) -> Timeline {
        try await cache()
    }
}
