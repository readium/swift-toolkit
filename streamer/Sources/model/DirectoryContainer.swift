//
//  DirectoryContainer.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/15/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// EPUB Container for EPUBs unzipped in a directory
open class EpubDirectoryContainer: EpubDataContainer {
    
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

    open func dataLength(relativePath: String) throws -> UInt64 {
        let fullPath = generateFullPath(with: relativePath)

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fullPath) else {
            throw EpubDataContainerError.fileError
        }
        guard let fileSize = attributes[FileAttributeKey.size] as? UInt64 else {
            throw EpubDataContainerError.fileError
        }

        return fileSize
        // OLD
        //        let fullPath = (rootPath as NSString).appendingPathComponent(relativePath)
        //        if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath) {
        //            let fileSize = attrs[FileAttributeKey.size] as! UInt64
        //
        //            return fileSize
        //        }
        //        throw EpubDataContainerError.fileError
    }

    open func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        let fullPath = generateFullPath(with: relativePath)

        guard let inputStream = FileInputStream(fileAtPath: fullPath) else {
            throw EpubDataContainerError.streamInitFailed
        }

        return inputStream
        // OLD
        //        let fullPath = (rootPath as NSString).appendingPathComponent(relativePath)
        //
        //        if let inputStream = FileInputStream(fileAtPath: fullPath) {
        //            return inputStream
        //        }
        //        throw EpubDataContainerError.streamInitFailed
    }

    private func generateFullPath(with relativePath: String) -> String {
        let fullPath = (rootPath as NSString).appendingPathComponent(relativePath)

        return fullPath
    }
}
