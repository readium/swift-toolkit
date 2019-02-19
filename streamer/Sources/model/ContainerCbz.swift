//
//  CbzContainer.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 3/31/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import R2Shared

extension ContainerCbz: Loggable {}

/// Container for archived CBZ publications.
public class ContainerCbz: CbzContainer, ZipArchiveContainer {
    public var attribute: [FileAttributeKey : Any]?
    
    /// See `RootFile`.
    public var rootFile: RootFile
    /// The zip archive object containing the Epub.
    var zipArchive: ZipArchive
    public var drm: Drm?


    /// Public failable initializer for the Container protocol.
    ///
    /// - Parameter path: Path to the archive file.
    public init?(path: String) {
        guard let arc = ZipArchive(url: URL(fileURLWithPath: path)) else {
            return nil
        }
        zipArchive = arc
        rootFile = RootFile.init(rootPath: path,
                                 mimetype: CbzConstant.mimetype)
        do {
            try zipArchive.buildFilesList()
        } catch {
            ContainerCbz.log(.error, "zipArchive error generating file List")
            return nil
        }
    }

    /// Returns an array of the containers contained files names.
    ///
    /// - Returns: The array of the container file's names.
    public func getFilesList() -> [String] {
        let archivedFilesList = zipArchive.fileInfos.map({
            $0.key
        }).sorted()
        
        return archivedFilesList
    }
}
