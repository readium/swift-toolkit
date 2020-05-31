//
//  PositionsService.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 30/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

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
    type: "application/vnd.readium.position-list+json",
    rel: "http://readium.org/position-list"
)

public extension PositionsService {
    
    var links: [Link] { [positionsLink] }

    func get(link: Link) -> Resource? {
        guard link.href == positionsLink.href else {
            return nil
        }
        
        let positions = self.positions
        let response: [String: Any] = [
            "total": positions.count,
            "positions": positions.json
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
        findService(PositionsService.self)?.positionsByReadingOrder ?? []
    }
    
    /// List of all the positions in the publication.
    var positions: [Locator] {
        findService(PositionsService.self)?.positions ?? []
    }
    
    /// List of all the positions in each resource, indexed by their `href`.
    @available(*, deprecated, message: "Use `positionsByReadingOrder` instead", renamed: "positionsByReadingOrder")
    var positionsByResource: [String: [Locator]] {
        Dictionary(grouping: positions, by: { $0.href })
    }

}


// MARK: PublicationServicesBuilder Helpers

public extension PublicationServicesBuilder {
    
    mutating func setPositions(_ factory: ((PublicationServiceContext) -> PositionsService?)?) {
        if let factory = factory {
            set(PositionsService.self, factory)
        } else {
            remove(PositionsService.self)
        }
    }
    
}
