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

    nonisolated func guidedNavigationDocumentHREF(for readingOrderHREF: any URLConvertible) -> AnyURL? {
        readingOrder.firstWithHREF(readingOrderHREF)?
            .alternates
            .firstWithMediaType(.smil)?
            .url()
    }

    func guidedNavigationDocument(
        at href: any URLConvertible
    ) async throws(ReadError) -> GuidedNavigationDocument? {
        let smilURL = href.anyURL

        if let cached = gndCache[smilURL] {
            return cached
        }
        let doc = try await retrieve(smilURL)
        // Use updateValue to properly store nil without removing the key.
        // A nil doc is a valid cached result (SMIL exists but has no guided
        // content), and the dictionary subscript setter treats `= nil` as
        // key removal, which would cause repeated re-parsing.
        gndCache.updateValue(doc, forKey: smilURL)
        return doc
    }

    private func retrieve(_ smilURL: AnyURL) async throws(ReadError) -> GuidedNavigationDocument? {
        guard let resource = container[smilURL] else {
            throw ReadError.decoding("SMIL not found at \(smilURL)")
        }

        let data = try await resource.read().get()
        do {
            return try SMILParser.parseGuidedNavigationDocument(
                smilData: data,
                at: smilURL
            )
        } catch {
            throw ReadError.decoding(error)
        }
    }
}
