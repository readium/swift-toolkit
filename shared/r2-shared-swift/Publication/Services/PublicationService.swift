//
//  PublicationService.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 30/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Base interface to be implemented by all publication services.
public protocol PublicationService {
    
    /// Links which will be added to `Publication.links`.
    /// It can be used to expose a web API for the service, through `Publication.get()`.
    ///
    /// To disambiguate the href with a publication's local resources, you should use the prefix
    /// `/~readium/`. A custom media type or rel should be used to identify the service.
    ///
    /// You can use a templated URI to accept query parameters, e.g.:
    /// ```
    /// Link(
    ///     href: "/~readium/search{?text}",
    ///     type: "application/vnd.readium.search+json",
    ///     templated: true
    /// )
    /// ```
    var links: [Link] { get }
    
    /// A service can return a Resource to:
    ///  - respond to a request to its web API declared in links,
    ///  - serve additional resources on behalf of the publication,
    ///  - replace a publication resource by its own version.
    ///
    /// Called by `Publication.get()` for each request.
    ///
    /// - Returns: The Resource containing the response, or null if the service doesn't recognize
    ///   this request.
    func get(link: Link) -> Resource?
    
    /// Closes any opened file handles, removes temporary files, etc.
    func close()

}

public extension PublicationService {
    
    var links: [Link] { [] }
    
    func get(link: Link) -> Resource? { return nil }
    
    func close() { }

}

/// Factory used to create a `PublicationService`.
public typealias PublicationServiceFactory = (PublicationServiceContext) -> PublicationService?

/// Container for the context from which a service is created.
public struct PublicationServiceContext {
    public let manifest: Manifest
    public let fetcher: Fetcher
}
