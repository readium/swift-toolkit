//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Timeline service for web publications, such as EPUB, built from the table
/// of contents of the publication.
///
/// Only the first entry pointing to each reading order resource is placed, at
/// the start of the resource. The other entries keep their place in the tree
/// without a range. A chapter split across several resources is therefore
/// located in all of them.
@_spi(ExperimentalTimeline)
public final class WebTimelineService: TimelineService {
    public static func makeFactory() -> TimelineServiceFactory {
        { context in
            WebTimelineService(publication: context.publication)
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
                resolver: WebTimelinePositionResolver(readingOrder: publication.readingOrder, nodes: nodes)
            )
        }
    }

    /// Builds the timeline once. A failure is not cached, so the next call
    /// tries again.
    public func timeline() async throws(ReadError) -> Timeline {
        try await cache()
    }
}
