//
//  DirectoryContainer.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/15/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// EPUB Container for EPUBs unzipped in a directory.
public class ContainerEpubDirectory: EpubContainer, DirectoryContainer {

    /// Struct containing meta information about the Container.
    public var rootFile: RootFile

    // MARK: - Public methods.

    /// Public failable initializer for the EpubDirectoryContainer class.
    ///
    /// - Parameter dirPath: The root directory path.
    public init?(directory path: String) {
        // FIXME: useless check probably. Always made before hand.
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        rootFile = RootFile.init(rootPath: path)
    }
}
