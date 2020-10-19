//
//  Copyright 2020 Readium Foundation. All rights reserved.
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
    var identifier: String? { get }
    
    /// Number of pages in the document.
    var pageCount: Int { get }
    
    /// The first page rendered as a cover.
    var cover: UIImage? { get }
    
    
    // Values extracted from the document information dictionary, defined in PDF specification.
    
    /// The document's title.
    var title: String? { get }
    
    /// The name of the person who created the document.
    var author: String? { get }
    
    /// The subject of the document.
    var subject: String? { get }
    
    /// Keywords associated with the document.
    var keywords: [String] { get }
    
    /// Outline to build the table of contents.
    var tableOfContents: [PDFOutlineNode] { get }
    
}

public protocol PDFDocumentFactory {
    
    /// Opens a PDF from a local file path.
    func open(url: URL, password: String?) throws -> PDFDocument
    
    /// Opens a PDF from a `Fetcher`'s resource.
    func open(resource: Resource, password: String?) throws -> PDFDocument
    
}

public class DefaultPDFDocumentFactory: PDFDocumentFactory, Loggable {
    
    /// The default PDF document factory uses Core Graphics.
    private let factory = CGPDFDocumentFactory()
    
    public init() {}
    
    public func open(url: URL, password: String?) throws -> PDFDocument {
        return try factory.open(url: url, password: password)
    }
    
    public func open(resource: Resource, password: String?) throws -> PDFDocument {
        return try factory.open(resource: resource, password: password)
    }
    
}

/// A PDF document factory which will iterate over a list of factories until one works.
public class CompositePDFDocumentFactory: PDFDocumentFactory, Loggable  {
    
    private let factories: [PDFDocumentFactory]
    
    public init(factories: [PDFDocumentFactory]) {
        self.factories = factories
    }
    
    public func open(url: URL, password: String?) throws -> PDFDocument {
        return try eachFactory { try $0.open(url: url, password: password) }
    }
    
    public func open(resource: Resource, password: String?) throws -> PDFDocument {
        return try eachFactory { try $0.open(resource: resource, password: password) }
    }
    
    private func eachFactory(tryOpen: (PDFDocumentFactory) throws -> PDFDocument) throws -> PDFDocument {
        for factory in factories {
            do {
                return try tryOpen(factory)
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
public protocol PDFPublicationService: class, PublicationService {
    
    /// Factory used by the publication service to open PDF documents.
    var pdfFactory: PDFDocumentFactory { get set }
    
}
