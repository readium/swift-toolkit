//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit

/// Allows extracting a `PDFKit.PDFDocument` from any `PDFDocument` implementation that wraps one,
/// without the caller needing to know about concrete types.
public protocol PDFKitDocumentProviding {
    var pdfKitDocument: PDFKit.PDFDocument { get }
}

extension PDFKit.PDFDocument: PDFKitDocumentProviding {
    public var pdfKitDocument: PDFKit.PDFDocument {
        self
    }
}

/// Extends PDFKit's `PDFDocument` with our shared `PDFDocument` protocol.
///
/// Unfortunately, PDFKit doesn't support streams, so we need to load the full document in memory.
/// If this is an issue for you, use `CPDFDocumentFactory` instead.
///
/// Use `PDFKitPDFDocumentFactory` to create a `PDFDocument` from a `Resource`.
extension PDFKit.PDFDocument: PDFDocument {
    public func pageCount() async throws -> Int {
        pageCount
    }

    public func identifier() async throws -> String? {
        try await documentRef?.identifier()
    }

    public func cover() async throws -> UIImage? {
        try await documentRef?.cover()
    }

    public func readingProgression() async throws -> ReadingProgression? {
        try await documentRef?.readingProgression()
    }

    public func title() async throws -> String? {
        try await documentRef?.title()
    }

    public func author() async throws -> String? {
        try await documentRef?.author()
    }

    public func subject() async throws -> String? {
        try await documentRef?.subject()
    }

    public func keywords() async throws -> [String] {
        try await documentRef?.keywords() ?? []
    }

    public func tableOfContents() async throws -> [PDFOutlineNode] {
        try await documentRef?.tableOfContents() ?? []
    }
}

extension PDFKit.PDFDocument: PDFDocumentTextProviding {
    public func pageText(at pageIndex: Int) async throws -> String? {
        page(at: pageIndex)?.string
    }
}

/// Creates a `PDFDocument` using PDFKit.
public class PDFKitPDFDocumentFactory: PDFDocumentFactory {
    public init() {}

    public func open(file: FileURL, password: String?) async throws -> PDFDocument {
        guard let document = PDFKit.PDFDocument(url: file.url) else {
            throw PDFDocumentError.openFailed
        }

        return try open(document: document, password: password)
    }

    public func open<HREF: URLConvertible>(resource: Resource, at href: HREF, password: String?) async throws -> PDFDocument {
        // Fast-path in case the resource actually references a file on the
        // disk.
        if let file = resource.sourceURL?.fileURL {
            return try await open(file: file, password: password)
        }

        // Unfortunately, PDFKit doesn't support streams, so we need to load the
        // full document in memory. If this is an issue for you, use
        // `CGPDFDocumentFactory` instead.
        //
        // We read chunk by chunk and monitor available memory to avoid OOM
        // crashes.
        let data: Data
        do {
            data = try await resource.readMonitoringMemory()
        } catch ReadError.cancelled {
            throw CancellationError()
        } catch {
            throw PDFDocumentError.reading(error)
        }

        guard let document = PDFKit.PDFDocument(data: data) else {
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
