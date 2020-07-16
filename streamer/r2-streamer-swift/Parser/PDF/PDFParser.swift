//
//  PDFParser.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 05.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import CoreGraphics
import R2Shared

/// Errors thrown during the parsing of the PDF.
public enum PDFParserError: Error {
    // The file at 'path' is missing from the container.
    case missingFile(path: String)
    // Failed to open the PDF
    case openFailed
    // The PDF is encrypted with a password. This is not supported right now.
    case fileEncryptedWithPassword
    // The LCP for PDF Package is malformed.
    case invalidLCPDF
}


public final class PDFParser: PublicationParser, Loggable {
    
    enum Error: Swift.Error {
        case fileNotReadable
    }

    private let parserType: PDFFileParser.Type
    
    public init(parserType: PDFFileParser.Type) {
        self.parserType = parserType
    }
    
    public func parse(file: File, fetcher: Fetcher, fallbackTitle: String, warnings: WarningLogger?) throws -> Publication.Components? {
        guard file.format == .pdf else {
            return nil
        }
        
        guard let stream = FileInputStream(fileAtPath: file.url.path) else {
            throw Error.fileNotReadable
        }

        let parser = try parserType.init(stream: stream)
        let pdfMetadata = try parser.parseMetadata()

        var authors: [Contributor] = []
        if let authorName = pdfMetadata.author {
            authors.append(Contributor(name: authorName))
        }

        let pdfHref = "/\(file.name)"

        return Publication.Components(
            fileFormat: .pdf,
            publicationFormat: .pdf,
            manifest: Manifest(
                metadata: Metadata(
                    identifier: pdfMetadata.identifier,
                    title: pdfMetadata.title ?? file.title,
                    authors: authors,
                    numberOfPages: try parser.parseNumberOfPages()
                ),
                readingOrder: [
                    Link(href: pdfHref, type: MediaType.pdf.string)
                ],
                tableOfContents: pdfMetadata.outline.links(withHref: pdfHref)
            ),
            fetcher: FileFetcher(href: pdfHref, path: file.url),
            servicesBuilder: PublicationServicesBuilder(
                cover: (try? parser.renderCover()).map(GeneratedCoverService.createFactory(cover:)),
                positions: PDFPositionsService.createFactory()
            )
        )
    }

    public static func parse(at url: URL) throws -> (PubBox, PubParsingCallback) {
        if Format.of(url) == .lcpProtectedPDF {
            return try ReadiumWebPubParser.parse(at: url)
        }
        
        let parser = PDFParser(parserType: PDFFileCGParser.self)
        guard let publication = try parser.parse(file: File(url: url), fetcher: makeFetcher(for: url))?.build() else {
            throw PDFParserError.openFailed
        }
        
        let container = PublicationContainer(
            publication: publication,
            path: url.path,
            mimetype: MediaType.pdf.string
        )
        
        return ((publication, container), { _ in })
    }

}
