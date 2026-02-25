//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A ``GuidedNavigationService`` to retrieve pre-authored Readium Guided
/// Navigation Documents.
///
/// Discovers Guided Navigation Documents via `link.alternates` on reading order
/// items.
actor ReadiumGuidedNavigationService: GuidedNavigationService {
    static func makeFactory() -> GuidedNavigationServiceFactory {
        { context in
            ReadiumGuidedNavigationService(
                manifest: context.manifest,
                container: context.container
            )
        }
    }

    nonisolated let manifest: Manifest
    private let container: Container
    private var gndCache: [AnyURL: GuidedNavigationDocument?] = [:]

    init(manifest: Manifest, container: Container) {
        self.manifest = manifest
        self.container = container
    }

    nonisolated var hasGuidedNavigation: Bool {
        manifest.readingOrder.contains {
            $0.alternates.anyMatchingMediaType(.readiumGuidedNavigationDocument)
        }
    }

    nonisolated func hasGuidedNavigation(for href: any URLConvertible) -> Bool {
        manifest.readingOrder.firstWithHREF(href)?
            .alternates
            .anyMatchingMediaType(.readiumGuidedNavigationDocument)
            ?? false
    }

    func guidedNavigationDocument(
        for href: any URLConvertible
    ) async throws(ReadError) -> GuidedNavigationDocument? {
        guard
            let readingOrderLink = manifest.readingOrder.firstWithHREF(href),
            let gnURL = readingOrderLink.alternates.firstWithMediaType(.readiumGuidedNavigationDocument)?.url()
        else {
            return nil
        }

        if let cached = gndCache[gnURL] {
            return cached
        }
        let doc = try await retrieve(gnURL)
        // Use updateValue to properly store nil without removing the key.
        // A nil doc is a valid cached result (document exists but has no
        // guided content), and the dictionary subscript setter treats
        // `= nil` as key removal, which would cause repeated re-parsing.
        gndCache.updateValue(doc, forKey: gnURL)
        return doc
    }

    private func retrieve(_ gnURL: AnyURL) async throws(ReadError) -> GuidedNavigationDocument? {
        guard let resource = container[gnURL] else {
            throw ReadError.decoding("Guided Navigation Document not found at \(gnURL)")
        }

        let json = try await resource.read().asJSONObject().get()
        do {
            return try GuidedNavigationDocument(json: json)
        } catch {
            throw ReadError.decoding(error)
        }
    }
}
