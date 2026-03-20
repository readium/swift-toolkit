//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias PositionsServiceFactory = (PublicationServiceContext) -> PositionsService?

/// Provides a list of discrete locations in the publication, no matter what the original format is.
public protocol PositionsService: PublicationService {
    /// List of all the positions in the publication, grouped by the resource reading order index.
    func positionsByReadingOrder() async throws(ReadError) -> [[Locator]]

    /// List of all the positions in the publication.
    func positions() async throws(ReadError) -> [Locator]
}

public extension PositionsService {
    func positions() async throws(ReadError) -> [Locator] {
        try await positionsByReadingOrder().flatMap { $0 }
    }
}

// MARK: Web Service

private let positionsLink = Link(
    href: "~readium/positions",
    mediaType: MediaType.readiumPositions
)

public extension PositionsService {
    var links: [Link] {
        [positionsLink]
    }

    func get<T: URLConvertible>(_ href: T) -> (any Resource)? {
        guard href.anyURL.isEquivalentTo(positionsLink.url()) else {
            return nil
        }
        return PositionsResource(positions: positions)
    }
}

private class PositionsResource: Resource {
    private let positions: () async throws(ReadError) -> [Locator]

    init(positions: @escaping () async throws(ReadError) -> [Locator]) {
        self.positions = positions
    }

    let sourceURL: AbsoluteURL? = nil

    func estimatedLength() async throws(ReadError) -> UInt64? {
        nil
    }

    func properties() async throws(ReadError) -> ResourceProperties {
        ResourceProperties()
    }

    func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async throws(ReadError) {
        let positions = try await positions()
        let response: [String: JSONValue] = .init([
            "total": positions.count,
            "positions": positions,
        ])

        guard let jsonResponse = try? response.jsonData() else {
            throw ReadError.decoding(JSONError.serializing(PositionsService.self))
        }

        consume(jsonResponse)
    }
}

// MARK: Publication Helpers

public extension Publication {
    /// List of all the positions in the publication, grouped by the resource reading order index.
    func positionsByReadingOrder() async throws(ReadError) -> [[Locator]] {
        if let service = findService(PositionsService.self) {
            return try await service.positionsByReadingOrder()
        } else {
            let positions = try await positionsFromManifest()
            let positionsByResource = Dictionary(grouping: positions, by: { $0.href })
            return readingOrder.map { positionsByResource[$0.url()] ?? [] }
        }
    }

    /// List of all the positions in the publication.
    func positions() async throws(ReadError) -> [Locator] {
        if let service = findService(PositionsService.self) {
            return try await service.positions()
        } else {
            return try await positionsFromManifest()
        }
    }

    /// Fetches the positions from a web service declared in the manifest, if there's one.
    private func positionsFromManifest() async throws(ReadError) -> [Locator] {
        guard let link = links.firstWithMediaType(.readiumPositions),
              let resource = get(link)
        else {
            return []
        }
        let data = try await resource.read()
        let json = try data.asJSONObjectValue()
        return json["positions"]?.decode() ?? []
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
