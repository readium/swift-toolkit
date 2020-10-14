//
//  PublicationServicesBuilder.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 30/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Builds a list of `PublicationService` from a collection of `PublicationServiceFactory`.
///
/// Provides helpers to manipulate the list of services of a `Publication`.
public struct PublicationServicesBuilder {
    
    private var factories: [String: PublicationServiceFactory] = [:]

    public init(setup: ((inout PublicationServicesBuilder) -> Void)? = nil) {
        setup?(&self)
    }
    
    public init(
        contentProtection: ContentProtectionServiceFactory? = nil,
        cover: CoverServiceFactory? = nil,
        positions: PositionsServiceFactory? = nil
    ) {
        self.init {
            $0.setContentProtectionServiceFactory(contentProtection)
            $0.setCoverServiceFactory(cover)
            $0.setPositionsServiceFactory(positions)
        }
    }

    /// Builds the actual list of publication services to use in a `Publication`.
    ///
    /// - Parameter context: Context provided to the service factories.
    public func build(context: PublicationServiceContext) -> [PublicationService] {
        return factories.values.compactMap { $0(context) }
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
