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
public actor ReadiumGuidedNavigationService: GuidedNavigationService {
    public static func makeFactory() -> GuidedNavigationServiceFactory {
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
    private var cachedGlobalDocument: ReadResult<GuidedNavigationDocument?>?

    init(manifest: Manifest, container: Container) {
        self.manifest = manifest
        self.container = container
    }

    public nonisolated var hasGuidedNavigation: Bool {
        manifest.links.anyMatchingMediaType(.readiumGuidedNavigationDocument)
            || manifest.readingOrder.contains { $0.alternates.anyMatchingMediaType(.readiumGuidedNavigationDocument) }
    }

    public nonisolated func hasGuidedNavigation(for href: any URLConvertible) -> Bool {
        manifest.readingOrder.firstWithHREF(href)?
            .alternates
            .anyMatchingMediaType(.readiumGuidedNavigationDocument)
            ?? false
    }

    public func guidedNavigationDocument(
        for href: any URLConvertible
    ) async -> ReadResult<GuidedNavigationDocument?> {
        guard
            let readingOrderLink = manifest.readingOrder.firstWithHREF(href),
            let gnURL = readingOrderLink.alternates.firstWithMediaType(.readiumGuidedNavigationDocument)?.url()
        else {
            return .success(nil)
        }

        if let cached = gndCache[gnURL] {
            return .success(cached)
        }
        let result = await retrieve(gnURL)
        if case let .success(doc) = result {
            gndCache[gnURL] = doc
        }
        return result
    }

    private func retrieve(_ gnURL: AnyURL) async -> ReadResult<GuidedNavigationDocument?> {
        guard let resource = container[gnURL] else {
            return .success(nil)
        }

        return await resource.readAsJSONObject()
            .flatMap { json in
                do {
                    return try .success(GuidedNavigationDocument(json: json))
                } catch {
                    return .failure(.decoding(error))
                }
            }
    }
}
