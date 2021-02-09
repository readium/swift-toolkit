//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
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

    /// Weak reference to the parent publication.
    ///
    /// Don't store directly the referenced publication, always access it through the `Weak` property.
    ///
    /// The publication won't be set when the service is created or when calling `PublicationService.links`, but you can
    /// use it during regular service operations. If you need to initialize your service differently depending on the
    /// publication, use `manifest`.
    public let publication: Weak<Publication>

    public let manifest: Manifest
    public let fetcher: Fetcher
}
