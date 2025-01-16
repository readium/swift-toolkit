//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias TableOfContentsServiceFactory = (PublicationServiceContext) -> TableOfContentsService?

/// Returns or computes a table of contents for the publication.
public protocol TableOfContentsService: PublicationService {
    func tableOfContents() async -> ReadResult<[Link]>
}

// MARK: Publication Helpers

public extension Publication {
    /// Returns the table of contents for this publication.
    func tableOfContents() async -> ReadResult<[Link]> {
        if let service = findService(TableOfContentsService.self) {
            return await service.tableOfContents()
        } else {
            return .success(manifest.tableOfContents)
        }
    }
}

// MARK: PublicationServicesBuilder Helpers

public extension PublicationServicesBuilder {
    mutating func setTableOfContentsServiceFactory(_ factory: TableOfContentsServiceFactory?) {
        if let factory = factory {
            set(TableOfContentsService.self, factory)
        } else {
            remove(TableOfContentsService.self)
        }
    }
}
