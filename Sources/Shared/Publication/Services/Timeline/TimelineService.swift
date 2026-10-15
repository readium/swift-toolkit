//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

@_spi(ExperimentalTimeline)
public typealias TimelineServiceFactory = @Sendable (PublicationServiceContext) -> TimelineService?

/// Provides the ``Timeline`` of a publication: its table of contents laid out
/// on the reading order, where each entry becomes an item with a start and an
/// end.
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
