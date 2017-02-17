//
//  EpubContainer.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/15/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// EPUB Container for EPUB files
open class EpubContainer: EpubDataContainer {
    var epubFilePath: String
    var zipArchive: ZipArchive

    public init?(path: String) {
        guard let arc = ZipArchive(url: URL(fileURLWithPath: path)) else {
            return nil
        }
        zipArchive = arc
        epubFilePath = path
    }

    open func data(relativePath: String) throws -> Data {
        return try zipArchive.readData(path: relativePath)
    }

    open func dataLength(relativePath: String) throws -> UInt64 {
        return try zipArchive.fileSize(path: relativePath)
    }

    open func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        // let inputStream = ZipInputStream(zipArchive: zipArchive, path: relativePath)
        guard let inputStream = ZipInputStream(zipFilePath: epubFilePath, path: relativePath) else {
            throw EpubDataContainerError.streamInitFailed
        }

        return inputStream
    }
}
