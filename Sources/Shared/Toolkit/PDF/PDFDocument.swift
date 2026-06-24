//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

public enum PDFDocumentError: Error, Sendable {
    /// The provided password was incorrect.
    case invalidPassword
    /// Impossible to open the given PDF.
    case openFailed
    /// An error occurred while reading the content.
    case reading(ReadError)
}

/// Represents a PDF document.
///
/// This is not used to render a PDF document, only to access its metadata.
public protocol PDFDocument: Sendable {
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

/// Refinement of `PDFDocument` for implementations that support text
/// extraction.
public protocol PDFDocumentTextProviding: PDFDocument {
    /// Returns the text content of the page at the given 0-based `pageIndex`,
    /// or `nil` when the page exists but carries no text layer.
    func pageText(at pageIndex: Int) async throws -> String?
}

public protocol PDFDocumentFactory: Sendable {
    /// Opens a PDF from a local file path.
    func open(file: FileURL, password: String?) async throws -> PDFDocument

    /// Opens a PDF from a `Resource` located at the given `href`.
    func open<HREF: URLConvertible & Sendable>(resource: Resource, at href: HREF, password: String?) async throws -> PDFDocument
}

public final class DefaultPDFDocumentFactory: PDFDocumentFactory, Loggable {
    private let factory = PDFKitPDFDocumentFactory()

    public init() {}

    public func open(file: FileURL, password: String?) async throws -> PDFDocument {
        try await factory.open(file: file, password: password)
    }

    public func open<HREF: URLConvertible & Sendable>(resource: Resource, at href: HREF, password: String?) async throws -> PDFDocument {
        try await factory.open(resource: resource, at: href, password: password)
    }
}
