//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias PositionsServiceFactory = (PublicationServiceContext) -> PositionsService?

/// Provides a list of discrete locations in the publication, no matter what the original format is.
public protocol PositionsService: PublicationService {
    /// List of all the positions in the publication, grouped by the resource reading order index.
    func positionsByReadingOrder() async -> ReadResult<[[Locator]]>

    /// List of all the positions in the publication.
    func positions() async -> ReadResult<[Locator]>
}

public extension PositionsService {
    func positions() async -> ReadResult<[Locator]> {
        await positionsByReadingOrder().map { $0.flatMap { $0 } }
    }
}

// MARK: Web Service

private let positionsLink = Link(
    href: "~readium/positions",
    mediaType: MediaType.readiumPositions
)

public extension PositionsService {
    var links: [Link] { [positionsLink] }

    func get<T>(_ href: T) -> (any Resource)? where T: URLConvertible {
        guard href.anyURL.isEquivalentTo(positionsLink.url()) else {
            return nil
        }
        return PositionsResource(positions: positions)
    }
}

private class PositionsResource: Resource {
    private let positions: () async -> ReadResult<[Locator]>

    init(positions: @escaping () async -> ReadResult<[Locator]>) {
        self.positions = positions
    }

    let sourceURL: AbsoluteURL? = nil

    func estimatedLength() async -> ReadResult<UInt64?> {
        .success(nil)
    }

    func properties() async -> ReadResult<ResourceProperties> {
        .success(ResourceProperties())
    }

    func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
        await positions().flatMap { positions in
            let response: [String: Any] = [
                "total": positions.count,
                "positions": positions.json,
            ]

            guard let jsonResponse = serializeJSONData(response) else {
                return .failure(.decoding(JSONError.serializing(PositionsService.self)))
            }

            consume(jsonResponse)
            return .success(())
        }
    }
}

// MARK: Publication Helpers

public extension Publication {
    /// List of all the positions in the publication, grouped by the resource reading order index.
    func positionsByReadingOrder() async -> ReadResult<[[Locator]]> {
        if let service = findService(PositionsService.self) {
            return await service.positionsByReadingOrder()
        } else {
            return await positionsFromManifest().map { positions in
                let positionsByResource = Dictionary(grouping: positions, by: { $0.href })
                return readingOrder.map { positionsByResource[$0.url()] ?? [] }
            }
        }
    }

    /// List of all the positions in the publication.
    func positions() async -> ReadResult<[Locator]> {
        if let service = findService(PositionsService.self) {
            return await service.positions()
        } else {
            return await positionsFromManifest()
        }
    }

    /// Fetches the positions from a web service declared in the manifest, if there's one.
    private func positionsFromManifest() async -> ReadResult<[Locator]> {
        await links.firstWithMediaType(.readiumPositions)
            .flatMap { get($0) }?
            .readAsJSONObject()
            .map { [Locator](json: $0["positions"]) }
            ?? .success([])
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
