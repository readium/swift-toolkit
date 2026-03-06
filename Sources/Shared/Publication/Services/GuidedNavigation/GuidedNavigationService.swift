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

    /// Returns the HREF of the pre-authored ``GuidedNavigationDocument``
    /// associated with the given reading order resource.
    func guidedNavigationDocumentHREF(for readingOrderHREF: any URLConvertible) -> AnyURL?

    /// Returns the pre-authored ``GuidedNavigationDocument`` at the given
    /// `href`, or `nil` if none is found.
    func guidedNavigationDocument(at href: any URLConvertible) async throws(ReadError) -> GuidedNavigationDocument?
}

// MARK: Publication Helpers

public extension Publication {
    /// Whether this publication has any pre-authored guided navigation
    /// documents.
    var hasGuidedNavigation: Bool {
        findService(GuidedNavigationService.self)?.hasGuidedNavigation ?? false
    }

    /// Returns the HREF of the pre-authored ``GuidedNavigationDocument``
    /// associated with the given reading order resource.
    func guidedNavigationDocumentHREF(for readingOrderHREF: any URLConvertible) -> AnyURL? {
        findService(GuidedNavigationService.self)?.guidedNavigationDocumentHREF(for: readingOrderHREF)
    }

    /// Returns the pre-authored ``GuidedNavigationDocument`` at the given
    /// `href`.
    func guidedNavigationDocument(at href: any URLConvertible) async throws(ReadError) -> GuidedNavigationDocument? {
        guard let service = findService(GuidedNavigationService.self) else {
            return nil
        }
        return try await service.guidedNavigationDocument(at: href)
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
