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
public struct PDFConstant {
    /// PDF mime-types.
    public static let pdfMimetype = "application/pdf"
    public static let lcpdfMimetype = "application/pdf+lcp"
    
    /// Default PDF file path inside the container, for standalone PDF files.
    public static let pdfFilePath = "/"
    /// HRef for the pre-rendered cover of standalone PDF files.
    public static let pdfFileCoverPath = "/cover.png"
    
    /// Relative path to the manifest of a LCPDF package.
    public static let lcpdfManifestPath = "/manifest.json"
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
    
    public static func parse(fileAtPath path: String) throws -> (PubBox, PubParsingCallback) {
        // Having `metadataParser` as an argument with default value doesn't satisfy the `PublicationParser` protocol...
        return try parse(fileAtPath: path, parserType: PDFFileCGParser.self)
    }
    
    /// Parses the PDF (file/directory) at `fileAtPath` and generates the corresponding `Publication` and `Container`.
    ///
    /// - Parameter fileAtPath: The path to the PDF file.
    /// - Parameter metadataParser: File metadata parser, you can provide your own implementation if you want to use a different PDF engine.
    /// - Returns: The Resulting publication, and a callback for parsing the possibly DRM encrypted metadata in the publication, once the DRM object is filled by a DRM module (eg. LCP).
    /// - Throws: `PDFParserError`
    public static func parse(fileAtPath path: String, parserType: PDFFileParser.Type) throws -> (PubBox, PubParsingCallback) {
        guard FileManager.default.fileExists(atPath: path) else {
            throw PDFParserError.missingFile(path: path)
        }
        
        let pubBox: PubBox
        switch path.pathExtension.lowercased() {
        case "pdf":
            pubBox = try parsePDF(at: path, parserType: parserType)
        case "lcpdf":
            pubBox = try parseLCPDF(at: path, parserType: parserType)
        default:
            throw PDFParserError.openFailed
        }

        func didLoadDRM(drm: DRM?) throws {
            pubBox.associatedContainer.drm = drm
        }
        
        return (pubBox, didLoadDRM)
    }

    private static func parsePDF(at path: String, parserType: PDFFileParser.Type) throws -> PubBox {
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
            format: .pdf,
            formatVersion: pdfMetadata.version,
            positionListFactory: makePositionListFactory(container: container, parserType: parserType),
            metadata: Metadata(
                identifier: pdfMetadata.identifier ?? container.rootFile.rootPath,
                title: pdfMetadata.title ?? titleFromPath(container.rootFile.rootPath),
                authors: authors,
                numberOfPages: try parser.parseNumberOfPages()
            ),
            readingOrder: [
                Link(href: documentHref, type: PDFConstant.pdfMimetype)
            ],
            resources: resources,
            tableOfContents: pdfMetadata.outline.links(withHref: documentHref)
        )
        
        return (publication, container)
    }

    private static func parseLCPDF(at path: String, parserType: PDFFileParser.Type) throws -> PubBox {
        guard let container = LCPDFContainer(path: path),
            let manifestData = try? container.data(relativePath: PDFConstant.lcpdfManifestPath),
            let manifestJSON = try? JSONSerialization.jsonObject(with: manifestData) else
        {
            throw PDFParserError.invalidLCPDF
        }
        
        let publication = try Publication(
            json: manifestJSON,
            normalizeHref: { normalize(base: container.rootFile.rootFilePath, href: $0) }
        )
        publication.format = .pdf
        publication.metadata.identifier = publication.metadata.identifier ?? container.rootFile.rootPath
        publication.positionListFactory = makePositionListFactory(container: container, parserType: parserType)
        
        // Checks the requirements from the spec, see. https://readium.org/lcp-specs/drafts/lcpdf
        guard publication.readingOrder.contains(where: { $0.type == PDFConstant.pdfMimetype }) else {
            throw PDFParserError.invalidLCPDF
        }
        
        return (publication, container)
    }

    private static func titleFromPath(_ path: String) -> String {
        return URL(fileURLWithPath: path)
            .deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
    }
    
    private static func makePositionListFactory(container: PDFContainer, parserType: PDFFileParser.Type) -> (Publication) -> [Locator] {
        return { publication -> [Locator] in
            // In case it's a single PDF and the numberOfPages was already parsed from the metadata.
            if publication.readingOrder.count == 1, let pageCount = publication.metadata.numberOfPages, pageCount > 0 {
                return makePositionList(of: publication.readingOrder[0], pageCount: pageCount)
            }
            
            // The resources could be encrypted, so we use the fetcher to go through the content filters.
            guard let fetcher = try? Fetcher(publication: publication, container: container) else {
                return []
            }

            var lastPositionOfPreviousResource = 0
            return publication.readingOrder.flatMap { link -> [Locator] in
                guard let optionalData = try? fetcher.data(forLink: link),
                    let data = optionalData,
                    let parser = try? parserType.init(stream: DataInputStream(data: data)),
                    let pageCount = try? parser.parseNumberOfPages(),
                    pageCount > 0 else
                {
                    log(.warning, "Can't get the number of pages from PDF document at \(link)")
                    return []
                }

                let positionList = makePositionList(of: link, pageCount: pageCount, startPosition: lastPositionOfPreviousResource)
                lastPositionOfPreviousResource += pageCount
                return positionList
            }
        }
    }
    
    private static func makePositionList(of link: Link, pageCount: Int, startPosition: Int = 0) -> [Locator] {
        assert(pageCount > 0, "Invalid PDF page count")
        
        return (1...pageCount).map { pageNumber in
            Locator(
                href: link.href,
                type: link.type ?? "application/pdf",
                // FIXME: title by finding the containing TOC item
                title: nil,
                locations: Locations(
                    fragment: "page=\(pageNumber)",
                    progression: Double(pageNumber) / Double(pageCount),
                    position: startPosition + pageNumber
                )
            )
        }
    }

}
