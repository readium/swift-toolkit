//
//  CbzParser.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/31/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

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

/// CBZ format parser.
public class CbzParser: PublicationParser {

    public init() {}

    public func parse(fileAtPath path: String) throws -> PubBox {
        // Generate the `Container` for `fileAtPath`
        let container: CbzContainer = try generateContainerFrom(fileAtPath: path)
        let publication = Publication()

        publication.metadata._title = title(from: path)
        publication.metadata.identifier = path
        publication.internalData["type"] = "cbz"
        publication.internalData["rootfile"] = container.rootFile.rootFilePath

        let files = container.getFilesList()
        for filename in files {
            let link = Link()

            link.typeLink = getMediaType(from: filename).rawValue
            link.href = filename
            guard link.typeLink != MediaType.invalid.rawValue else {
                continue
            }
            publication.spine.append(link)
        }
        return (publication, container)
    }

    private func title(from path: String) -> MultilangString {
        let fileUrl = URL(fileURLWithPath: path)
        let multilangString = MultilangString()
        let filename = fileUrl.lastPathComponent
        let title = filename.replacingOccurrences(of: "_", with: " ")

        multilangString.singleString = title
        return multilangString
    }

    /// Generate a Container instance for the file at `fileAtPath`. It handles
    /// 2 cases, epub files and unwrapped epub directories.
    ///
    /// - Parameter path: The absolute path of the file.
    /// - Returns: The generated Container.
    /// - Throws: `EpubParserError.missingFile`.
    fileprivate func generateContainerFrom(fileAtPath path: String) throws -> CbzContainer {
        var container: CbzContainer?
        var isDirectory: ObjCBool = false

        // TODO add support for CBZ directories
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw  CbzParserError.missingFile(path: path)
        }
        if isDirectory.boolValue {
            container = ContainerCbzDirectory(directory: path)
        } else {
            container = ContainerCbz(path: path)
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
