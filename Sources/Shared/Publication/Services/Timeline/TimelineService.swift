//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

@_spi(ExperimentalTimeline)
public typealias TimelineServiceFactory = @Sendable (PublicationServiceContext) -> TimelineService?

/// Provides the ``Timeline`` of a publication: its table of contents laid out
/// on the reading order, where each entry gets a start and an end.
///
/// Use it to find the chapter containing the current location, move to the
/// previous or next chapter, or get the boundaries and duration of each
/// chapter.
@_spi(ExperimentalTimeline)
public protocol TimelineService: PublicationService {
    /// Returns the timeline of the publication.
    func timeline() async throws(ReadError) -> Timeline
}

// MARK: Publication Helpers

public extension Publication {
    /// Returns the timeline of the publication, or `nil` when the publication
    /// has no timeline service.
    @_spi(ExperimentalTimeline)
    func timeline() async throws(ReadError) -> Timeline? {
        guard let service = findService(TimelineService.self) else {
            return nil
        }
        return try await service.timeline()
    }
}

// MARK: PublicationServicesBuilder Helpers

public extension PublicationServicesBuilder {
    @_spi(ExperimentalTimeline)
    mutating func setTimelineServiceFactory(_ factory: TimelineServiceFactory?) {
        if let factory = factory {
            set(TimelineService.self, factory)
        } else {
            remove(TimelineService.self)
        }
    }
}

// MARK: Service Helpers

extension Timeline {
    /// Builds the timeline of `publication` from its table of contents, with
    /// the resolver returned by `makeResolver`.
    ///
    /// The table of contents is empty when it fails to load, so that the
    /// segments still cover each resource.
    init(
        publication: Publication?,
        resolver makeResolver: (Publication, [Node]) async -> any TimelinePositionResolver
    ) async throws(ReadError) {
        guard let publication else {
            throw .unsupportedOperation(DebugError("The publication is no longer available"))
        }

        let nodes: [Node]
        switch await publication.tableOfContents() {
        case let .success(toc):
            nodes = Self.nodes(of: toc)
        case let .failure(error):
            publication.log(.warning, "Failed to read the table of contents of the timeline: \(error)")
            nodes = []
        }

        await self.init(nodes: nodes, resolver: makeResolver(publication, nodes))
    }

    /// Nodes of the table of contents `links`. An untitled entry is replaced
    /// by its children.
    private static func nodes(of links: [Link]) -> [Node] {
        links.flatMap { link -> [Node] in
            let children = nodes(of: link.children)
            guard let title = link.title?.orNilIfBlank() else {
                return children
            }
            return [Node(title: title, link: link, children: children)]
        }
    }
}
