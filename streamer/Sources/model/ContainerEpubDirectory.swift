//
//  DirectoryContainer.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/15/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import R2Shared

extension ContainerEpubDirectory: Loggable {}

/// Container for expended EPUB publications. (Directory)
public class ContainerEpubDirectory: DirectoryContainer {
    public var attribute: [FileAttributeKey : Any]?
    
    /// See `RootFile`.
    public var rootFile: RootFile
    public var drm: Drm?    

    /// Public failable initializer for the EpubDirectoryContainer class.
    ///
    /// - Parameter dirPath: The root directory path.
    public init?(directory path: String) {
        // FIXME: useless check probably. Always made before hand.
        guard FileManager.default.fileExists(atPath: path) else {
            ContainerEpubDirectory.log(level: .error, "File at \(path) not found.")
            return nil
        }
        rootFile = RootFile.init(rootPath: path)
    }
}
