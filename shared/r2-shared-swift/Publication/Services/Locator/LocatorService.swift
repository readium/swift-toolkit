//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias LocatorServiceFactory = (PublicationServiceContext) -> LocatorService?

/// Locates the destination of various sources (e.g. locators, progression, etc.) in the
/// publication.
///
/// This service can be used to implement a variety of features, such as:
///   - Jumping to a given position or total progression, by converting it first to a `Locator`.
///   - Converting a `Locator` which was created from an alternate manifest with a different reading
///     order. For example, when downloading a streamed manifest or offloading a package.
public protocol LocatorService: PublicationService {
    
    /// Locates the target of the given `locator`.
    func locate(_ locator: Locator) -> Locator?
    
    /// Locates the target at the given `progression` relative to the whole publication.
    func locate(progression: Double) -> Locator?
    
}


// MARK: Publication Helpers

public extension Publication {
    
    /// Locates the target of the given `locator`.
    ///
    /// If `locator.href` can be found in the reading order, `locator` will be returned directly.
    /// Otherwise, will attempt to find the closest match using `totalProgression`, `position`,
    /// `fragments`, etc.
    func locate(_ locator: Locator) -> Locator? {
        findService(LocatorService.self)?.locate(locator)
    }
    
    /// Locates the target at the given `progression` relative to the whole publication.
    func locate(progression: Double) -> Locator? {
        findService(LocatorService.self)?.locate(progression: progression)
    }

}


// MARK: PublicationServicesBuilder Helpers

public extension PublicationServicesBuilder {
    
    mutating func setLocatorServiceFactory(_ factory: LocatorServiceFactory?) {
        if let factory = factory {
            set(LocatorService.self, factory)
        } else {
            remove(LocatorService.self)
        }
    }

}
