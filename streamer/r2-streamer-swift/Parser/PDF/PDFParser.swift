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


/// PDF related constants.
private struct PDFConstant {
    /// Default PDF file path inside the container, for standalone PDF files.
    static let pdfFilePath = "/"
    /// HRef for the pre-rendered cover of standalone PDF files.
    static let pdfFileCoverPath = "/cover.png"
    
    /// Relative path to the manifest of a LCPDF package.
    static let lcpdfManifestPath = "/manifest.json"
}


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
        let path = url.path
        guard let container = PDFFileContainer(path: path),
            let stream = FileInputStream(fileAtPath: path) else
        {
            throw PDFParserError.openFailed
        }

        let parser = try parserType.init(stream: stream)
        container.files[PDFConstant.pdfFilePath] = .path(path)
        container.context = parser.context
        
        let pdfMetadata = try parser.parseMetadata()
        
        var authors: [Contributor] = []
        if let authorName = pdfMetadata.author {
            authors.append(Contributor(name: authorName))
        }
        
        var resources: [Link] = []
        if let cover = try parser.renderCover(), let coverData = cover.pngData() {
            container.files[PDFConstant.pdfFileCoverPath] = .data(coverData)
            resources.append(Link(
                href: PDFConstant.pdfFileCoverPath,
                type: "image/png",
                rel: "cover",
                height: Int(cover.size.height),
                width: Int(cover.size.width)
            ))
        }
        
        let documentHref = PDFConstant.pdfFilePath
        let publication = Publication(
            manifest: PublicationManifest(
                metadata: Metadata(
                    identifier: pdfMetadata.identifier ?? container.rootFile.rootPath,
                    title: pdfMetadata.title ?? titleFromPath(container.rootFile.rootPath),
                    authors: authors,
                    numberOfPages: try parser.parseNumberOfPages()
                ),
                readingOrder: [
                    Link(href: documentHref, type: MediaType.pdf.string)
                ],
                resources: resources,
                tableOfContents: pdfMetadata.outline.links(withHref: documentHref)
            ),
            servicesBuilder: PublicationServicesBuilder {
                $0.set(PositionsService.self, PDFPositionsService.create(context:))
            },
            format: .pdf,
            formatVersion: pdfMetadata.version
        )
        
        return ((publication, container), nil)
    }

    private static func parseLCPDF(at url: URL, parserType: PDFFileParser.Type) throws -> (PubBox, PubParsingCallback?) {
        let path = url.path
        guard
            var fetcher: R2Shared.Fetcher = ArchiveFetcher(archive: url),
            let container = LCPDFContainer(path: path),
            let manifestData = try? container.data(relativePath: PDFConstant.lcpdfManifestPath),
            let manifestJSON = try? JSONSerialization.jsonObject(with: manifestData) else
        {
            throw PDFParserError.invalidLCPDF
        }
        
        container.drm = parseLCPDFDRM(in: container)
        var didLoadDRM: PubParsingCallback? = nil
        
        if let decryptor = LCPDecryptor(drm: container.drm) {
            fetcher = TransformingFetcher(fetcher: fetcher, transformer: decryptor.decrypt)
            didLoadDRM = { drm in
                decryptor.license = drm?.license
            }
        }
        
        let publication = Publication(
            manifest: try PublicationManifest(
                json: manifestJSON,
                normalizeHref: { normalize(base: container.rootFile.rootFilePath, href: $0) }
            ),
            fetcher: fetcher,
            servicesBuilder: PublicationServicesBuilder {
                $0.set(PositionsService.self, LCPDFPositionsService.create(parserType: parserType))
            },
            format: .pdf
        )
        
        // Checks the requirements from the spec, see. https://readium.org/lcp-specs/drafts/lcpdf
        guard !publication.readingOrder.isEmpty, publication.readingOrder.filter(byType: .pdf) == publication.readingOrder else {
            throw PDFParserError.invalidLCPDF
        }

        return ((publication, container), didLoadDRM)
    }
    
    private static func parseLCPDFDRM(in container: Container) -> DRM? {
        guard let licenseLength = try? container.dataLength(relativePath: "license.lcpl"),
            licenseLength > 0 else
        {
            return nil
        }
        return DRM(brand: .lcp)
    }

    private static func titleFromPath(_ path: String) -> String {
        return URL(fileURLWithPath: path)
            .deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
    }

}
