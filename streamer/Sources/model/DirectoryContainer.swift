//
//  DirectoryContainer.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/15/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// EPUB Container for EPUBs unzipped in a directory.
open class EpubDirectoryContainer: Container {
    
    /// The root directory path
    var rootPath: String

    public init?(directory dirPath: String) {
        guard FileManager.default.fileExists(atPath: dirPath) else {
            return nil
        }
        rootPath = dirPath
    }
    
    open func data(relativePath: String) throws -> Data {
        let fullPath = generateFullPath(with: relativePath)

        return try Data(contentsOf: URL(fileURLWithPath: fullPath), options: [.mappedIfSafe])
    }


    /// <#Description#>
    ///
    /// - Parameter relativePath: <#relativePath description#>
    /// - Returns: <#return value description#>
    /// - Throws: <#throws value description#>
    open func dataLength(relativePath: String) throws -> UInt64 {
        let fullPath = generateFullPath(with: relativePath)

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fullPath) else {
            throw ContainerError.fileError
        }
        guard let fileSize = attributes[FileAttributeKey.size] as? UInt64 else {
            throw ContainerError.fileError
        }
        return fileSize
    }


    /// <#Description#>
    ///
    /// - Parameter relativePath: <#relativePath description#>
    /// - Returns: <#return value description#>
    /// - Throws: <#throws value description#>
    open func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        let fullPath = generateFullPath(with: relativePath)

        guard let inputStream = FileInputStream(fileAtPath: fullPath) else {
            throw ContainerError.streamInitFailed
        }
        return inputStream
    }


    /// Generate an absolute path to a ressource from a given relative path.
    ///
    /// - Parameter relativePath: The 'directory-relative' path to the ressource.
    /// - Returns: The absolute path to the ressource
    internal func generateFullPath(with relativePath: String) -> String {
        let fullPath: String

        fullPath = (relativePath as NSString).appendingPathComponent(relativePath)
        return fullPath
    }
}
