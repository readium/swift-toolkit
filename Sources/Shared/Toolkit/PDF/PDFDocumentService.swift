//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Publication-scoped cache and factory for PDF documents.
///
/// Replaces `PDFPublicationService` and `PDFDocumentHolder`. Opens the PDF once per HREF
/// and shares the result across the parser, navigator, and publication services.
package protocol PDFDocumentService: PublicationService {
    /// Returns the cached document if `href` matches, otherwise opens through the underlying factory,
    /// caches the result, and returns it.
    func openDocument<HREF: URLConvertible>(at href: HREF) async throws -> PDFDocument

    /// Returns the cached document if `href` matches, or `nil` otherwise.
    func cachedDocument<HREF: URLConvertible>(at href: HREF) async -> PDFDocument?

    /// Replaces the cached document. Use this to seed the cache (parser) or to override it with
    /// a different concrete type (navigator forcing PDFKit).
    func setCachedDocument<HREF: URLConvertible>(_ document: PDFDocument?, at href: HREF) async

    /// Clears all cached documents.
    func removeCachedDocuments() async
}

package actor DefaultPDFDocumentService: PDFDocumentService {
    private let factory: any PDFDocumentFactory
    private let container: Container
    private var cachedHREF: AnyURL?
    private var cached: PDFDocument?

    package init(
        factory: some PDFDocumentFactory,
        container: Container,
        cached: (href: AnyURL, document: PDFDocument)?
    ) {
        self.factory = factory
        self.container = container

        if let cached {
            self.cached = cached.document
            cachedHREF = cached.href
        }
    }

    package func openDocument<HREF: URLConvertible>(at href: HREF) async throws -> PDFDocument {
        if let cached, let cachedHREF, cachedHREF.isEquivalentTo(href) {
            return cached
        }

        guard let resource = container[href] else {
            throw PDFDocumentError.openFailed
        }

        let document = try await factory.open(resource: resource, at: href, password: nil)
        cachedHREF = href.anyURL
        cached = document
        return document
    }

    package func cachedDocument<HREF: URLConvertible>(at href: HREF) -> PDFDocument? {
        guard let cachedHREF, cachedHREF.isEquivalentTo(href) else {
            return nil
        }
        return cached
    }

    package func setCachedDocument<HREF: URLConvertible>(_ document: PDFDocument?, at href: HREF) {
        cachedHREF = document != nil ? href.anyURL : nil
        cached = document
    }

    package func removeCachedDocuments() {
        cachedHREF = nil
        cached = nil
    }

    package static func makeFactory(
        factory: some PDFDocumentFactory,
        cached: (href: AnyURL, document: PDFDocument)? = nil
    ) -> (PublicationServiceContext) -> DefaultPDFDocumentService {
        { context in DefaultPDFDocumentService(factory: factory, container: context.container, cached: cached) }
    }
}

// MARK: - Publication Helpers

package extension Publication {
    var pdfDocumentService: PDFDocumentService? {
        findService(PDFDocumentService.self)
    }
}

// MARK: - PublicationServicesBuilder Helpers

package extension PublicationServicesBuilder {
    mutating func setPDFDocumentServiceFactory(_ factory: PublicationServiceFactory?) {
        if let factory {
            set(PDFDocumentService.self, factory)
        } else {
            remove(PDFDocumentService.self)
        }
    }
}
