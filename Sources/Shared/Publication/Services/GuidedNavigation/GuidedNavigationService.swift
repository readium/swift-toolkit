//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias GuidedNavigationServiceFactory = (PublicationServiceContext) -> GuidedNavigationService?

/// Provides pre-authored ``GuidedNavigationDocument`` objects for individual
/// reading order resources.
public protocol GuidedNavigationService: PublicationService {
    /// Whether this publication has any pre-authored guided navigation
    /// documents at all.
    var hasGuidedNavigation: Bool { get }

    /// Returns whether a pre-authored ``GuidedNavigationDocument`` exists for
    /// the given reading order resource, without fetching or parsing it.
    func hasGuidedNavigation(for href: any URLConvertible) -> Bool

    /// Returns the pre-authored ``GuidedNavigationDocument`` for the given
    /// reading order resource, or `nil` if none exists for this resource.
    func guidedNavigationDocument(for href: any URLConvertible) async throws(ReadError) -> GuidedNavigationDocument?
}

// MARK: Publication Helpers

public extension Publication {
    /// Whether this publication has any pre-authored guided navigation
    /// documents.
    var hasGuidedNavigation: Bool {
        findService(GuidedNavigationService.self)?.hasGuidedNavigation ?? false
    }

    /// Returns whether a pre-authored guided navigation document exists for
    /// the given reading order resource.
    func hasGuidedNavigation(for href: any URLConvertible) -> Bool {
        findService(GuidedNavigationService.self)?.hasGuidedNavigation(for: href) ?? false
    }

    /// Returns the pre-authored guided navigation document for the given
    /// reading order resource, or `nil` if none exists.
    func guidedNavigationDocument(for href: any URLConvertible) async throws(ReadError) -> GuidedNavigationDocument? {
        guard let service = findService(GuidedNavigationService.self) else {
            return nil
        }
        return try await service.guidedNavigationDocument(for: href)
    }
}

// MARK: PublicationServicesBuilder Helpers

public extension PublicationServicesBuilder {
    mutating func setGuidedNavigationServiceFactory(_ factory: GuidedNavigationServiceFactory?) {
        if let factory {
            set(GuidedNavigationService.self, factory)
        } else {
            remove(GuidedNavigationService.self)
        }
    }
}
