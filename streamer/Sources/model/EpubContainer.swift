//
//  EpubContainer.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/15/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// EPUB Container for EPUB files.
public class EpubContainer: Container {

    /// Struct containing meta information about the Container
    public var metadata: ContainerMetadata

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
        metadata = ContainerMetadata.init(rootPath: path)
        zipArchive = arc
    }

    // MARK: - Open methods.

    // Implements Container protocol
    public func data(relativePath: String) throws -> Data {
        return try zipArchive.readData(path: relativePath)
    }

    // Implements Container protocol
    public func dataLength(relativePath: String) throws -> UInt64 {
        return try zipArchive.fileSize(path: relativePath)
    }

    // Implements Container protocol
    public func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        // let inputStream = ZipInputStream(zipArchive: zipArchive, path: relativePath)
        guard let inputStream = ZipInputStream(zipFilePath: metadata.rootPath,
                                               path: relativePath) else {
            throw ContainerError.streamInitFailed
        }
        return inputStream
    }
}
