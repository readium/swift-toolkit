//
//  Container.swift
//  R2Streamer
//
//  Created by Olivier Körner on 14/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation


public enum ContainerError: Error {
    case streamInitFailed
    case fileNotFound
    case fileError
}


/**
 EPUB container protocol, for access to raw data from the files in the container.
*/
public protocol Container {
    
    /**
     Get the raw (possibly encrypted) data of an asset in the container.
     
     - parameter relativePath: The relative path to the asset.

     - returns: The data of the asset.
    */
    func data(relativePath: String) throws -> Data

    /**
     Get the size of an asset in the container.
     
     - parameter relativePath: The relative path to the asset.
     
     - returns: The size of the asset.
    */
    func dataLength(relativePath: String) throws -> UInt64
    
    /**
     Get an seekable input stream with the bytes of the asset in the container.
 
     - parameter relativePath: The relative path to the asset.
 
     - returns: A seekable input stream.
    */
    func dataInputStream(relativePath: String) throws -> SeekableInputStream
}


/**
 EPUB Container protocol implementation for EPUBs unzipped in a directory.
*/
open class DirectoryContainer: Container {
    
    /// The root directory path
    var rootPath: String
    
    public init?(directory dirPath: String) {
        rootPath = dirPath
        if !FileManager.default.fileExists(atPath: rootPath) {
            return nil
        }
    }
    
    open func data(relativePath: String) throws -> Data {
        let fullPath = (rootPath as NSString).appendingPathComponent(relativePath)
        return try Data(contentsOf: URL(fileURLWithPath: fullPath), options: [.mappedIfSafe])
    }
    
    open func dataLength(relativePath: String) throws -> UInt64 {
        let fullPath = (rootPath as NSString).appendingPathComponent(relativePath)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath) {
            let fileSize = attrs[FileAttributeKey.size] as! UInt64
            return fileSize
        }
        throw ContainerError.fileError
    }
    
    open func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        let fullPath = (rootPath as NSString).appendingPathComponent(relativePath)
        if let inputStream = FileInputStream(fileAtPath: fullPath) {
            return inputStream
        }
        throw ContainerError.streamInitFailed
    }
}


/**
 EPUB Container protocol implementation for EPUB files
*/
open class EpubContainer: Container {
    
    var epubFilePath: String
    var zipArchive: ZipArchive
    
    public init?(path: String) {
        epubFilePath = path
        if let arc = ZipArchive(url: URL(fileURLWithPath: path)) {
            zipArchive = arc
        } else {
            return nil
        }
    }
    
    open func data(relativePath: String) throws -> Data {
        return try zipArchive.readData(path: relativePath)
    }
    
    open func dataLength(relativePath: String) throws -> UInt64 {
        return try zipArchive.fileSize(path: relativePath)
    }
    
    open func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        let inputStream = ZipInputStream(zipFilePath: epubFilePath, path: relativePath)
        //let inputStream = ZipInputStream(zipArchive: zipArchive, path: relativePath)
        if inputStream == nil {
            throw ContainerError.streamInitFailed
        }
        return inputStream!
    }
}
