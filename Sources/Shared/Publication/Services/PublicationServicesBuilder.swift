//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Builds a list of `PublicationService` from a collection of `PublicationServiceFactory`.
///
/// Provides helpers to manipulate the list of services of a `Publication`.
public struct PublicationServicesBuilder {
    private var factories: [String: PublicationServiceFactory] = [:]

    public init(
        content: ContentServiceFactory? = nil,
        contentProtection: ContentProtectionServiceFactory? = nil,
        cover: CoverServiceFactory? = nil,
        locator: LocatorServiceFactory? = { DefaultLocatorService(publication: $0.publication) },
        positions: PositionsServiceFactory? = nil,
        search: SearchServiceFactory? = nil,
        setup: (inout PublicationServicesBuilder) -> Void = { _ in }
    ) {
        setContentServiceFactory(content)
        setContentProtectionServiceFactory(contentProtection)
        setCoverServiceFactory(cover)
        setLocatorServiceFactory(locator)
        setPositionsServiceFactory(positions)
        setSearchServiceFactory(search)
        setup(&self)
    }

    /// Builds the actual list of publication services to use in a `Publication`.
    ///
    /// - Parameter context: Context provided to the service factories.
    public func build(context: PublicationServiceContext) -> [PublicationService] {
        factories.values.compactMap { $0(context) }
    }

    /// Sets the publication service factory for the given service type.
    public mutating func set<T>(_ serviceType: T.Type, _ factory: @escaping PublicationServiceFactory) {
        factories[String(describing: serviceType)] = factory
    }

    /// Removes any service factory associated with the given service type.
    public mutating func remove<T>(_ serviceType: T.Type) {
        factories.removeValue(forKey: String(describing: serviceType))
    }

    /// Decorates the service factory associated with the given service type using `transform`.
    public mutating func decorate<T>(_ serviceType: T.Type, _ transform: (PublicationServiceFactory?) -> PublicationServiceFactory) {
        let key = String(describing: serviceType)
        factories[key] = transform(factories[key])
    }
}
