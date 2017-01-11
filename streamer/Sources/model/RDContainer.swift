//
//  RDContainer.swift
//  R2Streamer
//
//  Created by Olivier Körner on 14/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation


/**
 EPUB container protocol, for access to raw data from the files in the container.
*/
protocol RDContainer {
    
    /**
     Get the raw (possibly encrypted) data of an asset in the container.
     
     - parameter relativePath: The relative path to the asset.

     - returns: The data of the asset.
    */
    func data(relativePath: String) throws -> Data?

    /**
     Get the raw (possibly encrypted) data bytes within a certain range of an asset in the container.
     
     - parameter relativePath: The relative path to the asset.
     - parameter byteRange: The range of the bytes to fetch.
     
     - returns: The data of the asset.
     */
    func data(relativePath: String, byteRange: Range<UInt64>) throws -> Data?
    
    /**
     Get the size of an asset in the container.
     
     - parameter relativePath: The relative path to the asset.
     
     - returns: The size of the asset.
    */
    func dataLength(relativePath: String) throws -> UInt64?
}


/**
 EPUB Container protocol implementation for EPUBs unzipped in a directory.
*/
class RDDirectoryContainer: RDContainer {
    
    /// The root directory path
    var rootPath: String
    
    init?(directory dirPath: String) {
        rootPath = dirPath
        if !FileManager.default.fileExists(atPath: rootPath) {
            return nil
        }
    }
    
    func data(relativePath: String) throws -> Data? {
        let fullPath = (rootPath as NSString).appendingPathComponent(relativePath)
        return try Data(contentsOf: URL(fileURLWithPath: fullPath), options: [.mappedIfSafe])
    }
    
    func data(relativePath: String, byteRange: Range<UInt64>) throws -> Data? {
        let fullPath = (rootPath as NSString).appendingPathComponent(relativePath)
        if let fileHandle = FileHandle(forReadingAtPath: fullPath) {
            defer {
                fileHandle.closeFile()
            }
            
            // Get file length
            fileHandle.seekToEndOfFile()
            let fileLength = fileHandle.offsetInFile
            
            // Check bounds
            var rangeOffset = byteRange.lowerBound
            var rangeLength = (byteRange.upperBound == UInt64.max) ? fileLength : UInt64(byteRange.count)
            
            if rangeLength == 0 {
                return nil
            }
            
            if rangeOffset > fileLength {
                rangeOffset = fileLength
            }
            if rangeOffset + rangeLength > fileLength {
                rangeLength = fileLength - rangeOffset
            }
            
            // Check the length is a valid Int
            if rangeLength > UInt64(Int.max) {
                rangeLength = UInt64(Int.max)
            }
            
            // Get the data
            fileHandle.seek(toFileOffset: rangeOffset)
            let data = fileHandle.readData(ofLength: Int(rangeLength))
            return data
        }
        return nil
    }
    
    func dataLength(relativePath: String) throws -> UInt64? {
        let fullPath = (rootPath as NSString).appendingPathComponent(relativePath)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath) {
            let fileSize = attrs[FileAttributeKey.size] as! UInt64
            return fileSize
        }
        return nil
    }
}


/**
 EPUB Container protocol implementation for EPUB files
*/
class RDEpubContainer: RDContainer {
    
    var epubFilePath: String
    var zipArchive: ZipArchive
    
    init?(path: String) {
        epubFilePath = path
        if let arc = ZipArchive(url: URL(fileURLWithPath: path)) {
            zipArchive = arc
        } else {
            return nil
        }
    }
    
    func data(relativePath: String) throws -> Data? {
        return try zipArchive.readData(path: relativePath)
    }
    
    func data(relativePath: String, byteRange: Range<UInt64>) throws -> Data? {
        return try zipArchive.readData(path: relativePath, range: byteRange)
    }
    
    func dataLength(relativePath: String) throws -> UInt64? {
        return try zipArchive.fileSize(path: relativePath)
    }
}
