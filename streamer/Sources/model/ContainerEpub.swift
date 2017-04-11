//
//  EpubContainer.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/15/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// EPUB Container for EPUB files.
public class ContainerEpub: EpubContainer, ZipArchiveContainer {

    /// Struct containing meta information about the Container
    public var rootFile: RootFile

    /// The zip archive object containing the Epub.
    var zipArchive: ZipArchive

    // MARK: - Public methods.

    /// Public failable initializer for the EpubContainer class.
    ///
    /// - Parameter path: Path to the epub file.
    public init?(path: String) {
        guard let arc = ZipArchive(url: URL(fileURLWithPath: path)) else {
            return nil
        }
        rootFile = RootFile.init(rootPath: path)
        zipArchive = arc
    }
}
