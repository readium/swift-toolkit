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
        
        let pubBox: PubBox
        switch format {
        case .pdf:
            pubBox = try parsePDF(at: url, parserType: parserType)
        case .lcpProtectedPDF:
            pubBox = try parseLCPDF(at: url, parserType: parserType)
        default:
            throw PDFParserError.openFailed
        }

        func didLoadDRM(drm: DRM?) throws {
            pubBox.associatedContainer.drm = drm
        }
        
        return (pubBox, didLoadDRM)
    }

    private static func parsePDF(at url: URL, parserType: PDFFileParser.Type) throws -> PubBox {
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
                Link(href: documentHref, type: MediaType.pdf.string)
            ],
            resources: resources,
            tableOfContents: pdfMetadata.outline.links(withHref: documentHref)
        )
        
        return (publication, container)
    }

    private static func parseLCPDF(at url: URL, parserType: PDFFileParser.Type) throws -> PubBox {
        let path = url.path
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
        publication.positionListFactory = makePositionListFactory(container: container, parserType: parserType)
        
        // Checks the requirements from the spec, see. https://readium.org/lcp-specs/drafts/lcpdf
        guard !publication.readingOrder.isEmpty, publication.readingOrder.filter(byType: .pdf) == publication.readingOrder else {
            throw PDFParserError.invalidLCPDF
        }
        
        container.drm = parseLCPDFDRM(in: container)
        
        return (publication, container)
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
    
    private static func makePositionListFactory(container: PDFContainer, parserType: PDFFileParser.Type) -> (Publication) -> [Locator] {
        return { publication -> [Locator] in
            // In case it's a single PDF and the numberOfPages was already parsed from the metadata.
            if publication.readingOrder.count == 1, let pageCount = publication.metadata.numberOfPages, pageCount > 0 {
                return makePositionList(of: publication.readingOrder[0], pageCount: pageCount, totalPageCount: pageCount)
            }
            
            // The resources could be encrypted, so we use the fetcher to go through the content filters.
            guard let fetcher = try? Fetcher(publication: publication, container: container) else {
                return []
            }

            // Calculates the page count of each resource from the reading order.
            let resources = publication.readingOrder.map { link -> (Int, Link) in
                guard let stream = try? fetcher.dataStream(forLink: link),
                    // FIXME: We should be able to use the stream directly here instead of reading it fully into a Data object, but somehow it fails with random access in CBCDRMInputStream.
                    let data = try? Data.reading(stream, bufferSize: 500000 /* 500 KB */),
                    let parser = try? parserType.init(stream: DataInputStream(data: data)),
                    let pageCount = try? parser.parseNumberOfPages() else
                {
                    log(.warning, "Can't get the number of pages from PDF document at \(link)")
                    return (0, link)
                }
                return (pageCount, link)
            }

            let totalPageCount = resources.reduce(0) { count, current in count + current.0 }
            
            var lastPositionOfPreviousResource = 0
            return resources.flatMap { pageCount, link -> [Locator] in
                guard pageCount > 0 else {
                    return []
                }
                let positionList = makePositionList(of: link, pageCount: pageCount, totalPageCount: totalPageCount, startPosition: lastPositionOfPreviousResource)
                lastPositionOfPreviousResource += pageCount
                return positionList
            }
        }
    }
    
    private static func makePositionList(of link: Link, pageCount: Int, totalPageCount: Int, startPosition: Int = 0) -> [Locator] {
        assert(pageCount > 0, "Invalid PDF page count")
        assert(totalPageCount > 0, "Invalid PDF total page count")
        
        return (1...pageCount).map { position in
            let progression = Double(position - 1) / Double(pageCount)
            let totalProgression = Double(startPosition + position - 1) / Double(totalPageCount)
            return Locator(
                href: link.href,
                type: link.type ?? MediaType.pdf.string,
                locations: .init(
                    fragments: ["page=\(position)"],
                    progression: progression,
                    totalProgression: totalProgression,
                    position: startPosition + position
                )
            )
        }
    }

}
