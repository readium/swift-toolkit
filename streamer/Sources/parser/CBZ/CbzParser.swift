//
//  CbzParser.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 3/31/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import R2Shared

/// Errors related to the CBZ publications.
///
/// - missingFile: The file at 'path' is missing from the container.
public enum CbzParserError: LocalizedError {
    case missingFile(path: String)
    
    public var errorDescription: String? {
        switch self {
        case .missingFile(let path):
            return "The file '\(path)' is missing."
        }
    }
}

/// CBZ related constants.
public struct CbzConstant {
    public static let mimetype = "application/x-cbr"
}

public enum MediaType: String {
    case jpeg = "image/jpeg"
    case png = "image/png"
    
    init?(filename: String) {
        switch filename.pathExtension.lowercased() {
        case "jpg", "jpeg":
            self = .jpeg
        case "png":
            self = .png
        default:
            return nil
        }
    }
    
}

/// CBZ publication parsing class.
public class CbzParser: PublicationParser {

    @available(*, deprecated, message: "Use the static method `CbzParser.parse()` instead of instantiationg `CbzParser`")
    public init() {}

    @available(*, deprecated, message: "Use the static method `CbzParser.parse()` instead of instantiationg `CbzParser`")
    public func parse(fileAtPath path: String) throws -> PubBox {
        // For legacy reason this parser used to be instantiated, compared to EPUBParser
        return try CbzParser.parse(fileAtPath: path).0
    }
    
    /// Parse the file at `fileAtPath` and return a `PubBox` object containing
    /// the resulting `Publication` and `Container` objects.
    ///
    /// - Parameter path: The path of the file to parse.
    /// - Returns: The resulting `PubBox` object.
    /// - Throws: Throws `CbzParserError.missingFile`.
    public static func parse(fileAtPath path: String) throws -> (PubBox, PubParsingCallback) {
        // Generate the `Container` for `fileAtPath`.
        let container: CBZContainer = try generateContainerFrom(fileAtPath: path)
        let publication = Publication()
        
        publication.updatedDate = container.modificationDate
        publication.metadata.multilangTitle = title(from: path)
        publication.metadata.identifier = path
        publication.internalData["type"] = "cbz"
        publication.internalData["rootfile"] = container.rootFile.rootFilePath

        var addedCover = false
        for (index, filename) in container.files.enumerated() {
            guard let mediaType = MediaType(filename: filename) else {
                continue
            }
            
            let link = Link(
                href: normalize(base: container.rootFile.rootFilePath, href: filename),
                type: mediaType.rawValue
            )

            // First valid resource is cover.
            if !addedCover {
                link.rels.append("cover")
                addedCover = true
            }
            
            publication.readingOrder.append(link)
        }
        
        func didLoadDRM(drm: DRM?) {
            container.drm = drm
        }
        
        return ((publication, container), didLoadDRM)
    }

    /// Generate a MultilangString title from the publication at `path`.
    ///
    /// - Parameter path: The path of the publication.
    /// - Returns: The resulting MultilangString.
    private static func title(from path: String) -> MultilangString {
        let fileUrl = URL(fileURLWithPath: path)
        let multilangString = MultilangString()
        let filename = fileUrl.lastPathComponent
        let title = filename.replacingOccurrences(of: "_", with: " ")

        multilangString.singleString = title
        return multilangString
    }

    /// Generate a Container instance for the file at `fileAtPath`. It handles
    /// 2 cases, CBZ files and CBZ epub directories.
    ///
    /// - Parameter path: The absolute path of the file.
    /// - Returns: The generated Container.
    /// - Throws: `EpubParserError.missingFile`.
    private static func generateContainerFrom(fileAtPath path: String) throws -> CBZContainer {
        var container: CBZContainer?
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw CbzParserError.missingFile(path: path)
        }
        if isDirectory.boolValue {
            container = CBZDirectoryContainer(directory: path)
        } else {
            container = CBZArchiveContainer(path: path)
        }
        
        guard let containerUnwrapped = container else {
            throw CbzParserError.missingFile(path: path)
        }
        return containerUnwrapped
    }

}
