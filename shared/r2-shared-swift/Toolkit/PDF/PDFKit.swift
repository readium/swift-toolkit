//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit

/// Extends PDFKit's `PDFDocument` with our shared `PDFDocument` protocol.
///
/// Unfortunately, PDFKit doesn't support streams, so we need to load the full document in memory.
/// If this is an issue for you, use `CPDFDocumentFactory` instead.
///
/// Use `PDFKitPDFDocumentFactory` to create a `PDFDocument` from a `Resource`.
@available(iOS 11.0, *)
extension PDFKit.PDFDocument: PDFDocument {
    
    public var identifier: String? { documentRef?.identifier }

    public var cover: UIImage? { documentRef?.cover }
    
    public var title: String? { documentRef?.title }
    
    public var author: String? { documentRef?.author }
    
    public var subject: String? { documentRef?.subject }
    
    public var keywords: [String] { documentRef?.keywords ?? [] }
    
    public var tableOfContents: [PDFOutlineNode] { documentRef?.tableOfContents ?? [] }

}

/// Creates a `PDFDocument` using PDFKit.
@available(iOS 11.0, *)
public class PDFKitPDFDocumentFactory: PDFDocumentFactory {
    
    public func open(url: URL, password: String?) throws -> PDFDocument {
        guard let document = PDFKit.PDFDocument(url: url) else {
            throw PDFDocumentError.openFailed
        }
        
        return try open(document: document, password: password)
    }
    
    public func open(resource: Resource, password: String?) throws -> PDFDocument {
        // Unfortunately, PDFKit doesn't support streams, so we need to load the full document in
        // memory. If this is an issue for you, use `CPDFDocumentFactory` instead.
        guard
            let data = try? resource.read().get(),
            let document = PDFKit.PDFDocument(data: data)
        else {
            throw PDFDocumentError.openFailed
        }
        
        return try open(document: document, password: password)
    }
    
    private func open(document: PDFKit.PDFDocument, password: String?) throws -> PDFDocument {
        if document.isLocked {
            guard
                let password = password,
                document.unlock(withPassword: password)
            else {
                throw PDFDocumentError.invalidPassword
            }
        }
        
        return document
    }
    
}
