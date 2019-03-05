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
import R2Shared


/// PDF related constants.
public struct PDFConstant {
    /// PDF mime-type.
    public static let mimetype = "application/pdf"
    /// PDF file path inside the container.
    public static let pdfFilePath = "/publication.pdf"
}


/// Errors thrown during the parsing of the PDF.
public enum PDFParserError: LocalizedError {
    // The file at 'path' is missing from the container.
    case missingFile(path: String)
    
    public var errorDescription: String? {
        switch self {
        case .missingFile(let path):
            return "The file '\(path)' is missing."
        }
    }
    
}


public final class PDFParser: PublicationParser {

    /// PDFParser contains only static methods.
    private init() {}
    
    /// Parses the PDF (file/directory) at `fileAtPath` and generates the corresponding `Publication` and `Container`.
    ///
    /// - Parameter fileAtPath: The path to the PDF file.
    /// - Returns: The Resulting publication, and a callback for parsing the possibly DRM encrypted metadata in the publication, once the DRM object is filled by a DRM module (eg. LCP).
    /// - Throws: `PDFParserError`
    public static func parse(fileAtPath path: String) throws -> (PubBox, PubParsingCallback) {
        let container = try generateContainerFrom(fileAtPath: path)
        
        let publication = Publication()
        publication.updatedDate = container.modificationDate
        publication.internalData["type"] = "pdf"
        publication.internalData["rootfile"] = container.rootFile.rootFilePath
        
        // FIXME: pull metadata from the PDF itself
        publication.metadata.multilangTitle = title(from: path)
        publication.metadata.identifier = path
        
        let link = Link()
        link.typeLink = PDFConstant.mimetype
        link.href = PDFConstant.pdfFilePath
        publication.readingOrder.append(link)
        
        func didLoadDRM(drm: DRM?){
            container.drm = drm
        }
        
        return ((publication, container), didLoadDRM)
    }

    static private func generateContainerFrom(fileAtPath path: String) throws -> Container {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw PDFParserError.missingFile(path: path)
        }
        
        var container: Container?
        if isDirectory.boolValue {
            container = DirectoryContainer(directory: path, mimetype: PDFConstant.mimetype)
        } else {
            // FIXME: Which relative path to use here? It depends on how the fetcher access it
            container = FileContainer(path: path, relativePath: PDFConstant.pdfFilePath, mimetype: PDFConstant.mimetype)
        }
        
        guard let containerUnwrapped = container else {
            throw PDFParserError.missingFile(path: path)
        }
        return containerUnwrapped
    }
    
    static private func title(from path: String) -> MultilangString {
        let title = URL(fileURLWithPath: path)
            .deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
        
        return MultilangString(single: title)
    }

}
