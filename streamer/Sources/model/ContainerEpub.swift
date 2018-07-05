//
//  EpubContainer.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/15/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import R2Shared

extension ContainerEpub: Loggable {}

/// Container for EPUB publications. (Archived)
public class ContainerEpub: ZipArchiveContainer {
    public var attribute: [FileAttributeKey : Any]?
    
    /// See `RootFile`.
    public var rootFile: RootFile
    /// The zip archive object containing the Epub.
    var zipArchive: ZipArchive
    public var drm: Drm?

    /// Public failable initializer for the EpubContainer class.
    ///
    /// - Parameter path: Path to the epub file.
    public init?(path: String) {
        guard let arc = ZipArchive(url: URL(fileURLWithPath: path)) else {
            ContainerEpub.log(level: .error, "File at \(path) not found.")
            return nil
        }

        rootFile = RootFile.init(rootPath: path, mimetype: EpubConstant.mimetype)
        zipArchive = arc
    }
}
