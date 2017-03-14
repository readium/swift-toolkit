//
//  DirectoryContainer.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/15/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// EPUB Container for EPUBs unzipped in a directory.
public class EpubDirectoryContainer: Container {

    /// Struct containing meta information about the Container.
    public var metadata: ContainerMetadata

    // MARK: - Public methods.

    /// Public failable initializer for the EpubDirectoryContainer class.
    ///
    /// - Parameter dirPath: The root directory path.
    public init?(directory dirPath: String) {
        // FIXME: useless check probably. Always made before hand.
        guard FileManager.default.fileExists(atPath: dirPath) else {
            return nil
        }
        metadata = ContainerMetadata.init(rootPath: dirPath)
    }

    // MARK: - Open methods.

    // Implements Container protocol
    public func data(relativePath: String) throws -> Data {
        let fullPath = generateFullPath(with: relativePath)

        return try Data(contentsOf: URL(fileURLWithPath: fullPath), options: [.mappedIfSafe])
    }

    // Implements Container protocol
    public func dataLength(relativePath: String) throws -> UInt64 {
        let fullPath = generateFullPath(with: relativePath)

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fullPath) else {
            throw ContainerError.fileError
        }
        guard let fileSize = attributes[FileAttributeKey.size] as? UInt64 else {
            throw ContainerError.fileError
        }
        return fileSize
    }

    // Implements Container protocol
    public func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        let fullPath = generateFullPath(with: relativePath)

        guard let inputStream = FileInputStream(fileAtPath: fullPath) else {
            throw ContainerError.streamInitFailed
        }
        return inputStream
    }

    // MARK: - Internal methods

    /// Generate an absolute path to a ressource from a given relative path.
    ///
    /// - Parameter relativePath: The 'directory-relative' path to the ressource.
    /// - Returns: The absolute path to the ressource
    internal func generateFullPath(with relativePath: String) -> String {
        let fullPath = metadata.rootPath.appending(pathComponent: relativePath)
        
        return fullPath
    }
}
