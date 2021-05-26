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

    private let pdfFactory: PDFDocumentFactory
    
    public init(pdfFactory: PDFDocumentFactory = DefaultPDFDocumentFactory()) {
        self.pdfFactory = pdfFactory
    }
    
    public func parse(asset: PublicationAsset, fetcher: Fetcher, warnings: WarningLogger?) throws -> Publication.Builder? {
        guard asset.mediaType() == .pdf else {
            return nil
        }
       
        let readingOrder = fetcher.links.filter(byMediaType: .pdf)
        guard let firstLink = readingOrder.first else {
            throw PDFDocumentError.openFailed
        }
        
        let resource = fetcher.get(firstLink)
        let document = try pdfFactory.open(resource: resource, password: nil)
        let authors = Array(ofNotNil: document.author.map { Contributor(name: $0) })

        return Publication.Builder(
            mediaType: .pdf,
            format: .pdf,
            manifest: Manifest(
                metadata: Metadata(
                    identifier: document.identifier,
                    title: document.title ?? asset.name,
                    authors: authors,
                    numberOfPages: document.pageCount
                ),
                readingOrder: readingOrder,
                tableOfContents: document.tableOfContents.links(withDocumentHREF: firstLink.href)
            ),
            fetcher: fetcher,
            servicesBuilder: PublicationServicesBuilder(
                cover: document.cover.map(GeneratedCoverService.makeFactory(cover:)),
                positions: PDFPositionsService.makeFactory()
            )
        )
    }
    
    @available(*, unavailable, message: "Use `init(pdfFactory:)` instead")
    public convenience init(parserType: PDFFileParser.Type) {
        self.init(pdfFactory: PDFFileParserFactory(parserType: parserType))
    }

    @available(*, unavailable, message: "Use an instance of `Streamer` to open a `Publication`")
    public static func parse(at url: URL) throws -> (PubBox, PubParsingCallback) {
        fatalError("Not available")
    }

}
