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
    /// PDF mime-type.
    public static let mimetype = "application/pdf"
    
    /// Default PDF file path inside the container, for standalone PDF files.
    public static let pdfFilePath = "/publication.pdf"
    /// HRef for the pre-rendered cover of standalone PDF files.
    public static let pdfFileCoverPath = "/cover.png"
}


/// Errors thrown during the parsing of the PDF.
public enum PDFParserError: LocalizedError {
    // The file at 'path' is missing from the container.
    case missingFile(path: String)
    // Failed to open the PDF
    case openFailed
    // The PDF is encrypted with a password. This is not supported right now.
    case fileEncryptedWithPassword
    
    public var errorDescription: String? {
        switch self {
        case .missingFile(let path):
            return "The file '\(path)' is missing."
        case .openFailed:
            return "Can't open the PDF file."
        case .fileEncryptedWithPassword:
            return "The PDF is encrypted with a password."
        }
    }
    
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
        let container = try generateContainerFrom(fileAtPath: path)

        let publication = Publication()
        publication.updatedDate = container.modificationDate
        publication.internalData["type"] = "pdf"
        publication.internalData["rootfile"] = container.rootFile.rootFilePath

        // FIXME: if the PDF is DRM-protected, this will not work here
        if let fileContainer: PDFFileContainer = container as? PDFFileContainer {
            fileContainer.files[PDFConstant.pdfFilePath] = .path(path)
            
            let link = Link()
            link.typeLink = PDFConstant.mimetype
            link.href = PDFConstant.pdfFilePath
            publication.readingOrder.append(link)

            try self.fillMetadata(of: publication, in: fileContainer, parserType: parserType)
        }
        
        func didLoadDRM(drm: DRM?) throws {
            container.drm = drm
        }
        
        return ((publication, container), didLoadDRM)
    }

    private static func generateContainerFrom(fileAtPath path: String) throws -> PDFContainer {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
            let container = PDFFileContainer(path: path, mimetype: PDFConstant.mimetype) else
        {
            throw PDFParserError.missingFile(path: path)
        }
        return container
    }
    
    /// Extracts the metadata of a PDF file to fill the `Publication`.
    private static func fillMetadata(of publication: Publication, in container: PDFFileContainer, parserType: PDFFileParser.Type) throws {
        /// The PDF might be encrypted, so we filter it with the fetcher.
        guard let fetcher = try? Fetcher(publication: publication, container: container),
            let link = publication.readingOrder.first,
            let optionalStream = try? fetcher.dataStream(forLink: link),
            let stream = optionalStream else
        {
            throw PDFParserError.openFailed
        }
        
        let parser = try parserType.init(stream: stream)
        let metadata = try parser.parseMetadata()
        container.context = parser.context
        
        if let cover = try parser.renderCover(), let coverData = cover.pngData() {
            container.files[PDFConstant.pdfFileCoverPath] = .data(coverData)
            
            let link = Link()
            link.typeLink = "image/png"
            link.href = PDFConstant.pdfFileCoverPath
            link.rel.append("cover")
            publication.resources.append(link)
        }

        publication.metadata.identifier = metadata.identifier ?? container.rootFile.rootPath

        if let version = metadata.version {
            publication.version = Double(version) ?? 0
        }

        if let authorName = metadata.author {
            let author = Contributor()
            author.multilangName = MultilangString(single: authorName)
            publication.metadata.authors.append(author)
        }

        let title = metadata.title
            ?? URL(fileURLWithPath: container.rootFile.rootPath)
                .deletingPathExtension()
                .lastPathComponent
                .replacingOccurrences(of: "_", with: " ")
        publication.metadata.multilangTitle = MultilangString(single: title)
    }

}
