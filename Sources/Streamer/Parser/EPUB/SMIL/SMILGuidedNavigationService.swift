//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A ``GuidedNavigationService`` for EPUB 3 publications with SMIL Media
/// Overlay documents.
///
/// Discovers SMIL documents via `link.alternates` on reading order items, as
/// populated by ``EPUBParser``.
actor SMILGuidedNavigationService: GuidedNavigationService {
    static func makeFactory() -> GuidedNavigationServiceFactory {
        { context in
            SMILGuidedNavigationService(
                readingOrder: context.manifest.readingOrder,
                container: context.container
            )
        }
    }

    nonisolated let readingOrder: [Link]
    private let container: Container
    private var gndCache: [AnyURL: GuidedNavigationDocument?] = [:]

    init(readingOrder: [Link], container: Container) {
        self.readingOrder = readingOrder
        self.container = container
    }

    nonisolated var hasGuidedNavigation: Bool {
        readingOrder.contains {
            $0.alternates.anyMatchingMediaType(.smil)
        }
    }

    nonisolated func hasGuidedNavigation(for href: any URLConvertible) -> Bool {
        readingOrder.firstWithHREF(href)?
            .alternates
            .anyMatchingMediaType(.smil)
            ?? false
    }

    func guidedNavigationDocument(
        for href: any URLConvertible
    ) async -> ReadResult<GuidedNavigationDocument?> {
        guard
            let link = readingOrder.firstWithHREF(href),
            let smilURL = link.alternates.firstWithMediaType(.smil)?.url()
        else {
            return .success(nil)
        }

        if let cached = gndCache[smilURL] {
            return .success(cached)
        }
        let result = await retrieve(smilURL)
        if case let .success(doc) = result {
            gndCache[smilURL] = doc
        }
        return result
    }

    private func retrieve(_ smilURL: AnyURL) async -> ReadResult<GuidedNavigationDocument?> {
        guard let resource = container[smilURL] else {
            return .success(nil)
        }

        return await resource.read()
            .flatMap { data in
                do {
                    return try .success(
                        SMILParser.parseGuidedNavigationDocument(
                            smilData: data,
                            at: smilURL
                        )
                    )
                } catch {
                    return .failure(.decoding(error))
                }
            }
    }
}
