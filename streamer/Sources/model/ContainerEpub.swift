//
//  EpubContainer.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 2/15/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
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
    public var drm: DRM?

    /// Public failable initializer for the EpubContainer class.
    ///
    /// - Parameter path: Path to the epub file.
    public init?(path: String) {
        guard let arc = ZipArchive(url: URL(fileURLWithPath: path)) else {
            ContainerEpub.log(.error, "File at \(path) not found.")
            return nil
        }

        rootFile = RootFile.init(rootPath: path, mimetype: EpubConstant.mimetype)
        zipArchive = arc
    }
}
