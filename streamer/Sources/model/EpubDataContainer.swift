//
//  Container.swift
//  R2Streamer
//
//  Created by Olivier Körner on 14/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation

/// Container Protocol's Errors
public enum EpubDataContainerError: Error {
    //TODO: document
    case streamInitFailed
    case fileNotFound
    case fileError
}

//TODO: rename protocol, current name not clear
/// EPUB container protocol, for accessing raw data from container's files
public protocol EpubDataContainer {

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
