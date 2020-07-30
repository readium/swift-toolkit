//
//  CBZParser.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 3/31/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

/// Errors related to the CBZ publications.
///
/// - missingFile: The file at 'path' is missing from the container.
public enum CBZParserError: Error {
    case missingFile(path: String)
}

@available(*, deprecated, renamed: "CBZParserError")
public typealias CbzParserError = CBZParserError

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
    /// - Parameter url: The path of the file to parse.
    /// - Returns: The resulting `PubBox` object.
    /// - Throws: Throws `CBZParserError.missingFile`.
    public static func parse(at url: URL) throws -> (PubBox, PubParsingCallback) {
        let container = try generateContainerFrom(fileAtPath: url.path)
        let publication = parsePublication(in: container, at: url)

        func didLoadDRM(drm: DRM?) {
            container.drm = drm
        }
        
        return ((publication, container), didLoadDRM)
    }
    
    private static func parsePublication(in container: CBZContainer, at url: URL) -> Publication {
        var didSetCover = false
        let publication = Publication(
            format: .cbz,
            positionListFactory: makePositionList(of:),
            metadata: Metadata(
                title: url.deletingPathExtension()
                    .lastPathComponent
                    .replacingOccurrences(of: "_", with: " ")
            ),
            readingOrder: container.files
                .compactMap { filename in
                    guard let format = Format.of(fileExtension: filename.pathExtension),
                        format.mediaType.isBitmap else
                    {
                        return nil
                    }
                    
                    var rel: String?
                    
                    // First valid resource is the cover.
                    if !didSetCover {
                        didSetCover = true
                        rel = "cover"
                    }
                    
                    return Link(
                        href: normalize(base: container.rootFile.rootFilePath, href: filename),
                        type: format.mediaType.string,
                        rel: rel
                    )
                }
        )
        
        return publication
    }

    /// Generate a Container instance for the file at `fileAtPath`. It handles
    /// 2 cases, CBZ files and CBZ directories.
    ///
    /// - Parameter path: The absolute path of the file.
    /// - Returns: The generated Container.
    /// - Throws: `CBZParserError.missingFile`.
    private static func generateContainerFrom(fileAtPath path: String) throws -> CBZContainer {
        var container: CBZContainer?
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw CBZParserError.missingFile(path: path)
        }
        if isDirectory.boolValue {
            container = CBZDirectoryContainer(directory: path)
        } else {
            container = CBZArchiveContainer(path: path)
        }
        
        guard let containerUnwrapped = container else {
            throw CBZParserError.missingFile(path: path)
        }
        return containerUnwrapped
    }
    
    private static func makePositionList(of publication: Publication) -> [Locator] {
        let pageCount = publication.readingOrder.count
        return publication.readingOrder.enumerated().map { index, link in
            Locator(
                href: link.href,
                type: link.type ?? "",
                title: link.title,
                locations: .init(
                    totalProgression: Double(index) / Double(pageCount),
                    position: index + 1
                )
            )
        }
    }

}
