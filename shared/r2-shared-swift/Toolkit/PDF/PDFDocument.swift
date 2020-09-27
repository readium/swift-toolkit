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
    var outline: [PDFOutlineNode] { get }
    
}

public protocol PDFDocumentFactory {
    
    /// Opens a PDF from a local file path.
    func open(url: URL, password: String?) throws -> PDFDocument
    
    /// Opens a PDF from a `Fetcher`'s resource.
    func open(resource: Resource, password: String?) throws -> PDFDocument
    
}

public class DefaultPDFDocumentFactory: PDFDocumentFactory, Loggable {
    
    public init() {}
    
    public func open(url: URL, password: String?) throws -> PDFDocument {
        warnIfMainThread()
        return try CGPDFDocument(url: url, password: password)
    }
    
    public func open(resource: Resource, password: String?) throws -> PDFDocument {
        warnIfMainThread()
        return try CGPDFDocument(resource: resource, password: password)
    }
    
}
