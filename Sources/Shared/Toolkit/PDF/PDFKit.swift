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

/// Creates a `PDFDocument` using PDFKit.
public final class PDFKitPDFDocumentFactory: PDFDocumentFactory {
    public init() {}

    public func open(file: FileURL, password: String?) async throws -> PDFDocument {
        guard let document = PDFKit.PDFDocument(url: file.url) else {
            throw PDFDocumentError.openFailed
        }

        return try open(document: document, password: password)
    }

    public func open<HREF: URLConvertible & Sendable>(resource: Resource, at href: HREF, password: String?) async throws -> PDFDocument {
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

        return PDFKitPDFDocument(document)
    }
}

/// Wraps a PDFKit `PDFDocument` to expose it through the toolkit's
/// `PDFDocument` protocol.
///
/// Use `PDFKitPDFDocumentFactory` to create a `PDFKitPDFDocument` from a
/// `Resource`.
///
/// ## Concurrency
///
/// `PDFKit.PDFDocument` is a reference type with mutable internal state and is
/// not annotated as `Sendable` by Apple. Rather than retroactively asserting
/// `@unchecked Sendable` on the system type – which would leak that unsound
/// claim to *every* `PDFKit.PDFDocument` in the app – we confine the assertion
/// to this wrapper. The toolkit only performs read-only operations on the
/// document, and a given instance must not be mutated (e.g. by adding
/// `PDFAnnotation`s) while it is shared across threads.
// FIXME: Note that we share this instance with the PDF navigator through the `PDFDocumentService`. For now this is safe as we only perform read-only operations on the document. But this might change when we start adding `PDFAnnotation`, for example. We might need to revisit this implementation and have a PDFDocument dedicated to the navigator.
private final class PDFKitPDFDocument: PDFDocument, PDFDocumentTextProviding, PDFKitDocumentProviding, @unchecked Sendable {
    let pdfKitDocument: PDFKit.PDFDocument

    init(_ document: PDFKit.PDFDocument) {
        pdfKitDocument = document
    }

    func pageCount() async throws -> Int {
        pdfKitDocument.pageCount
    }

    func identifier() async throws -> String? {
        try await pdfKitDocument.documentRef?.identifier()
    }

    func cover() async throws -> UIImage? {
        try await pdfKitDocument.documentRef?.cover()
    }

    func readingProgression() async throws -> ReadingProgression? {
        try await pdfKitDocument.documentRef?.readingProgression()
    }

    func title() async throws -> String? {
        try await pdfKitDocument.documentRef?.title()
    }

    func author() async throws -> String? {
        try await pdfKitDocument.documentRef?.author()
    }

    func subject() async throws -> String? {
        try await pdfKitDocument.documentRef?.subject()
    }

    func keywords() async throws -> [String] {
        try await pdfKitDocument.documentRef?.keywords() ?? []
    }

    func tableOfContents() async throws -> [PDFOutlineNode] {
        try await pdfKitDocument.documentRef?.tableOfContents() ?? []
    }

    func pageText(at pageIndex: Int) async throws -> String? {
        pdfKitDocument.page(at: pageIndex)?.string
    }
}
