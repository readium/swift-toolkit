//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

public enum PDFDocumentError: Error {
    /// The provided password was incorrect.
    case invalidPassword
    /// Impossible to open the given PDF.
    case openFailed
}

/// Represents a PDF document.
///
/// This is not used to render a PDF document, only to access its metadata.
public protocol PDFDocument {
    /// Permanent identifier based on the contents of the file at the time it was originally
    /// created.
    func identifier() async throws -> String?

    /// Number of pages in the document.
    func pageCount() async throws -> Int

    /// The first page rendered as a cover.
    func cover() async throws -> UIImage?

    /// Reading progression set with the "Binding" property in Acrobat.
    func readingProgression() async throws -> ReadingProgression?

    // Values extracted from the document information dictionary, defined in PDF specification.

    /// The document's title.
    func title() async throws -> String?

    /// The name of the person who created the document.
    func author() async throws -> String?

    /// The subject of the document.
    func subject() async throws -> String?

    /// Keywords associated with the document.
    func keywords() async throws -> [String]

    /// Outline to build the table of contents.
    func tableOfContents() async throws -> [PDFOutlineNode]
}

public protocol PDFDocumentFactory {
    /// Opens a PDF from a local file path.
    func open(file: FileURL, password: String?) async throws -> PDFDocument

    /// Opens a PDF from a `Resource` located at the given `href`.
    func open<HREF: URLConvertible>(resource: Resource, at href: HREF, password: String?) async throws -> PDFDocument
}

public class DefaultPDFDocumentFactory: PDFDocumentFactory, Loggable {
    /// The default PDF document factory uses Core Graphics.
    private let factory = CGPDFDocumentFactory()

    public init() {}

    public func open(file: FileURL, password: String?) async throws -> PDFDocument {
        try await factory.open(file: file, password: password)
    }

    public func open<HREF: URLConvertible>(resource: Resource, at href: HREF, password: String?) async throws -> PDFDocument {
        try await factory.open(resource: resource, at: href, password: password)
    }
}

/// A PDF document factory which will iterate over a list of factories until one works.
public class CompositePDFDocumentFactory: PDFDocumentFactory, Loggable {
    private let factories: [PDFDocumentFactory]

    public init(factories: [PDFDocumentFactory]) {
        self.factories = factories
    }

    public func open(file: FileURL, password: String?) async throws -> PDFDocument {
        try await eachFactory { try await $0.open(file: file, password: password) }
    }

    public func open<HREF: URLConvertible>(resource: Resource, at href: HREF, password: String?) async throws -> PDFDocument {
        try await eachFactory { try await $0.open(resource: resource, at: href, password: password) }
    }

    private func eachFactory(tryOpen: (PDFDocumentFactory) async throws -> PDFDocument) async throws -> PDFDocument {
        for factory in factories {
            do {
                return try await tryOpen(factory)
            } catch PDFDocumentError.openFailed {
                continue
            }
        }
        throw PDFDocumentError.openFailed
    }
}

/// Protocol to be implemented by publication services using an overridable PDF factory.
///
/// This can be used for optimization reasons: to avoid opening a PDF document several times. For
/// example, if a PDF document was opened by a PDF Navigator, we can reuse its instance when used by
/// a PositionsService. In this case, the PDF Navigator can overwrite the `pdfFactory` property
/// of all the services conforming to `PDFPublicationService`.
public protocol PDFPublicationService: AnyObject, PublicationService {
    /// Factory used by the publication service to open PDF documents.
    var pdfFactory: PDFDocumentFactory { get set }
}
