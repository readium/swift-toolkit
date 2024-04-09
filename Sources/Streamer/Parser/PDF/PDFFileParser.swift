//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared
import UIKit

/// Structure holding the metadata from a standalone PDF file.
@available(*, unavailable, message: "Use `PDFDocument` from r2-shared instead")
public struct PDFFileMetadata {
    // Permanent identifier based on the contents of the file at the time it was originally created.
    let identifier: String?

    // The version of the PDF specification to which the document conforms (for example, 1.4).
    let version: String?

    /// Values extracted from the document information dictionary, defined in PDF specification.

    // The document's title.
    let title: String?
    // The name of the person who created the document.
    let author: String?
    // The subject of the document.
    let subject: String?
    // Keywords associated with the document.
    let keywords: [String]
    // Outline to build the table of contents.
    let outline: [PDFOutlineNode]
}

@available(*, unavailable, message: "Use `PDFDocument` from r2-shared instead")
public struct PDFOutlineNode {
    let title: String?
    let pageNumber: Int
    let children: [PDFOutlineNode]
}

@available(*, unavailable)
extension Array where Element == PDFOutlineNode {
    @available(*, unavailable)
    func links(withHref href: String) -> [Link] { [] }
}

/// Protocol to implement if you want to use a different PDF engine than the one provided with Readium 2 to parse the PDF's metadata.
/// Note: this is not used in the case of .lcpdf files, since the metadata are parsed from the manifest.json file.
@available(*, unavailable, message: "Use `PDFDocumentFactory` from r2-shared instead")
public protocol PDFFileParser: PDFDocument {
    /// Initializes the parser with the given PDF data stream.
    /// You must `open` and `close` the stream when needed.
    init(stream: SeekableInputStream) throws

    /// Renders the PDF's first page.
    func renderCover() throws -> UIImage?

    /// Parses the number of pages in the PDF.
    func parseNumberOfPages() throws -> Int

    /// Parses the PDF file metadata.
    func parseMetadata() throws -> PDFFileMetadata
}

@available(*, unavailable)
public extension PDFFileParser {
    @available(*, unavailable)
    var identifier: String? { try? parseMetadata().identifier }
    @available(*, unavailable)
    var pageCount: Int { (try? parseNumberOfPages()) ?? 0 }
    @available(*, unavailable)
    var cover: UIImage? { try? renderCover() }
    @available(*, unavailable)
    var title: String? { try? parseMetadata().title }
    @available(*, unavailable)
    var author: String? { try? parseMetadata().author }
    @available(*, unavailable)
    var subject: String? { try? parseMetadata().subject }
    @available(*, unavailable)
    var keywords: [String] { (try? parseMetadata().keywords) ?? [] }
    @available(*, unavailable)
    var outline: [R2Shared.PDFOutlineNode] { [] }
}

@available(*, unavailable)
extension PDFOutlineNode {
    @available(*, unavailable)
    func asShared() -> R2Shared.PDFOutlineNode { fatalError("Unavailable") }
}

@available(*, unavailable, message: "Use `PDFDocumentFactory` from r2-shared instead")
class PDFFileParserFactory: PDFDocumentFactory {
    enum Error: Swift.Error {
        case invalidFile(URL)
    }

    private let parserType: PDFFileParser.Type

    init(parserType: PDFFileParser.Type) {
        self.parserType = parserType
    }

    func open(resource: Resource, password: String?) throws -> PDFDocument {
        try parserType.init(stream: ResourceInputStream(resource: resource, length: resource.length.get()))
    }

    func open(url: URL, password: String?) throws -> PDFDocument {
        guard let stream = FileInputStream(fileAtPath: url.path) else {
            throw Error.invalidFile(url)
        }
        return try parserType.init(stream: stream)
    }
}
