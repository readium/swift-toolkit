//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias PositionsServiceFactory = (PublicationServiceContext) -> PositionsService?

/// Provides a list of discrete locations in the publication, no matter what the original format is.
public protocol PositionsService: PublicationService {
    /// List of all the positions in the publication, grouped by the resource reading order index.
    var positionsByReadingOrder: [[Locator]] { get }

    /// List of all the positions in the publication.
    var positions: [Locator] { get }
}

public extension PositionsService {
    var positions: [Locator] { positionsByReadingOrder.flatMap { $0 } }
}

// MARK: Web Service

private let positionsLink = Link(
    href: "/~readium/positions",
    type: MediaType.readiumPositions.string
)

public extension PositionsService {
    var links: [Link] { [positionsLink] }

    func get(link: Link) -> Resource? {
        guard link.href == positionsLink.href else {
            return nil
        }

        let positions = positions
        let response: [String: Any] = [
            "total": positions.count,
            "positions": positions.json,
        ]

        guard let jsonResponse = serializeJSONString(response) else {
            return FailureResource(
                link: positionsLink,
                error: .other(JSONError.serializing(PositionsService.self))
            )
        }

        return DataResource(link: positionsLink, string: jsonResponse)
    }
}

// MARK: Publication Helpers

public extension Publication {
    /// List of all the positions in the publication, grouped by the resource reading order index.
    var positionsByReadingOrder: [[Locator]] {
        if let positions = findService(PositionsService.self)?.positionsByReadingOrder {
            return positions
        }

        let positionsByResource = Dictionary(grouping: positionsFromManifest(), by: { $0.href })
        return readingOrder.map { positionsByResource[$0.href] ?? [] }
    }

    /// List of all the positions in the publication.
    var positions: [Locator] {
        findService(PositionsService.self)?.positions
            ?? positionsFromManifest()
    }

    /// List of all the positions in each resource, indexed by their `href`.
    @available(*, unavailable, message: "Use `positionsByReadingOrder` instead", renamed: "positionsByReadingOrder")
    var positionsByResource: [String: [Locator]] {
        Dictionary(grouping: positions, by: { $0.href })
    }

    /// Fetches the positions from a web service declared in the manifest, if there's one.
    private func positionsFromManifest() -> [Locator] {
        links.first(withMediaType: .readiumPositions)
            .map { get($0) }?
            .readAsJSON()
            .map { $0["positions"] }
            .map { [Locator](json: $0) }
            .getOrNil()
            ?? []
    }
}

// MARK: PublicationServicesBuilder Helpers

public extension PublicationServicesBuilder {
    mutating func setPositionsServiceFactory(_ factory: PositionsServiceFactory?) {
        if let factory = factory {
            set(PositionsService.self, factory)
        } else {
            remove(PositionsService.self)
        }
    }
}
