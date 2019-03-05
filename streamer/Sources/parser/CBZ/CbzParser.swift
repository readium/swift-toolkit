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
public enum CbzParserError: Error {
    case missingFile(path: String)
}

/// CBZ related constants.
public struct CbzConstant {
    public static let mimetype = "application/x-cbr"
}

public enum MediaType: String {
    case jpeg = "image/jpeg"
    case png = "image/png"
    case invalid = ""
}

/// CBZ publication parsing class.
public class CbzParser {

    public init() {}

    /// Parse the file at `fileAtPath` and return a `PubBox` object containing
    /// the resulting `Publication` and `Container` objects.
    ///
    /// - Parameter path: The path of the file to parse.
    /// - Returns: The resulting `PubBox` object.
    /// - Throws: Throws `CbzParserError.missingFile`.
    public func parse(fileAtPath path: String) throws -> PubBox {
        // Generate the `Container` for `fileAtPath`.
        let container: CBZContainer = try generateContainerFrom(fileAtPath: path)
        let publication = Publication()
        
        publication.updatedDate = container.modificationDate
        publication.metadata.multilangTitle = title(from: path)
        publication.metadata.identifier = path
        publication.internalData["type"] = "cbz"
        publication.internalData["rootfile"] = container.rootFile.rootFilePath

        var hasCoverLink = false

        for filename in container.files {
            let link = Link()

            link.typeLink = getMediaType(from: filename).rawValue
            guard link.typeLink != MediaType.invalid.rawValue else {
                continue
            }
            // First resource is cover.
            if !hasCoverLink {
                link.rel.append("cover")
                hasCoverLink = true
            }
            link.href = normalize(base: container.rootFile.rootFilePath, href: filename)
            publication.readingOrder.append(link)
        }
        return (publication, container)
    }

    /// Generate a MultilangString title from the publication at `path`.
    ///
    /// - Parameter path: The path of the publication.
    /// - Returns: The resulting MultilangString.
    private func title(from path: String) -> MultilangString {
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
    fileprivate func generateContainerFrom(fileAtPath path: String) throws -> CBZContainer {
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

    /// Return the mediatype (mimetype) of the given file, using it's extension.
    ///
    /// - Parameter filename: The filename.
    /// - Returns: The associated MediaType.
    fileprivate func getMediaType(from filename: String) -> MediaType {
        let mediaType: MediaType
        let pathExtension = filename.pathExtension

        switch pathExtension.lowercased() {
        case "jpg":
            mediaType = .jpeg
        case "jpeg":
            mediaType = .jpeg
        case "png":
            mediaType = .png
        default:
            mediaType = .invalid
        }
        return mediaType
    }
}
