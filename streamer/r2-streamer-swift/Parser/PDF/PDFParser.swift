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

    /// PDFParser contains only static methods.
    private init() {}
    
    public static func parse(at url: URL) throws -> (PubBox, PubParsingCallback) {
        // Having `metadataParser` as an argument with default value doesn't satisfy the `PublicationParser` protocol...
        return try parse(at: url, parserType: PDFFileCGParser.self)
    }
    
    /// Parses the PDF (file/directory) at `fileAtPath` and generates the corresponding `Publication` and `Container`.
    ///
    /// - Parameter url: The path to the PDF file.
    /// - Parameter metadataParser: File metadata parser, you can provide your own implementation if you want to use a different PDF engine.
    /// - Returns: The Resulting publication, and a callback for parsing the possibly DRM encrypted metadata in the publication, once the DRM object is filled by a DRM module (eg. LCP).
    /// - Throws: `PDFParserError`
    public static func parse(at url: URL, parserType: PDFFileParser.Type) throws -> (PubBox, PubParsingCallback) {
        guard FileManager.default.fileExists(atPath: url.path),
            let format = Format.of(url) else
        {
            throw PDFParserError.openFailed
        }
        
        let (pubBox, parsingCallback): (PubBox, PubParsingCallback?) = try {
            switch format {
            case .pdf:
                return try parsePDF(at: url, parserType: parserType)
            case .lcpProtectedPDF:
                return try parseLCPDF(at: url, parserType: parserType)
            default:
                throw PDFParserError.openFailed
            }
        }()

        func didLoadDRM(drm: DRM?) throws {
            try parsingCallback?(drm)
            pubBox.associatedContainer.drm = drm
        }
        
        return (pubBox, didLoadDRM)
    }

    private static func parsePDF(at url: URL, parserType: PDFFileParser.Type) throws -> (PubBox, PubParsingCallback?) {
        guard let stream = FileInputStream(fileAtPath: url.path) else {
            throw PDFParserError.openFailed
        }

        let parser = try parserType.init(stream: stream)
        let pdfMetadata = try parser.parseMetadata()

        var authors: [Contributor] = []
        if let authorName = pdfMetadata.author {
            authors.append(Contributor(name: authorName))
        }

        let pdfHref = "/publication.pdf"

        let publication = Publication(
            manifest: Manifest(
                metadata: Metadata(
                    identifier: pdfMetadata.identifier,
                    title: pdfMetadata.title ?? url.title,
                    authors: authors,
                    numberOfPages: try parser.parseNumberOfPages()
                ),
                readingOrder: [
                    Link(href: pdfHref, type: MediaType.pdf.string)
                ],
                tableOfContents: pdfMetadata.outline.links(withHref: pdfHref)
            ),
            fetcher: FileFetcher(href: pdfHref, path: url),
            servicesBuilder: PublicationServicesBuilder(
                cover: (try? parser.renderCover()).map(GeneratedCoverService.createFactory(cover:)),
                positions: PDFPositionsService.createFactory()
            ),
            format: .pdf,
            formatVersion: pdfMetadata.version
        )
        
        let container = PublicationContainer(
            publication: publication,
            path: url.path,
            mimetype: MediaType.pdf.string
        )
        
        return ((publication, container), nil)
    }

    private static func parseLCPDF(at url: URL, parserType: PDFFileParser.Type) throws -> (PubBox, PubParsingCallback?) {
        guard
            var fetcher: Fetcher = try? ArchiveFetcher(url: url),
            let manifestJSON = try? fetcher.get("/manifest.json").readAsJSON().get() else
        {
            throw PDFParserError.invalidLCPDF
        }
        
        let drm = DRM(brand: .lcp)
        var didLoadDRM: PubParsingCallback? = nil
        
        if let decryptor = LCPDecryptor(drm: drm) {
            fetcher = TransformingFetcher(fetcher: fetcher, transformer: decryptor.decrypt)
            didLoadDRM = { drm in
                decryptor.license = drm?.license
            }
        }
        
        let publication = Publication(
            manifest: try Manifest(
                json: manifestJSON,
                normalizeHref: { normalize(base: "", href: $0) }
            ),
            fetcher: fetcher,
            servicesBuilder: PublicationServicesBuilder(
                positions: LCPDFPositionsService.createFactory(parserType: parserType)
            ),
            format: .pdf
        )
        
        // Checks the requirements from the spec, see. https://readium.org/lcp-specs/drafts/lcpdf
        guard !publication.readingOrder.isEmpty, publication.readingOrder.all(matchMediaType: .pdf) else {
            throw PDFParserError.invalidLCPDF
        }
        
        let container = PublicationContainer(
            publication: publication,
            path: url.path,
            mimetype: MediaType.lcpProtectedPDF.string,
            drm: drm
        )

        return ((publication, container), didLoadDRM)
    }

}
