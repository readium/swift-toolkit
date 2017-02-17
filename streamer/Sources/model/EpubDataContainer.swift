//
//  Container.swift
//  R2Streamer
//
//  Created by Olivier Körner on 14/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation

/// EpubDataContainer Protocol's Errors
///
/// - streamInitFailed:
/// - fileNotFound:
/// - fileError:
public enum EpubDataContainerError: Error {
    case streamInitFailed
    case fileNotFound
    case fileError
}

//TODO: naming
/// EPUB container protocol, for accessing raw data from container's files
public protocol EpubDataContainer {

    /// Get the raw (possibly encrypted) data of an asset in the container
    ///
    /// - Parameter relativePath: The relative path to the asset.
    /// - Returns: The data of the asset.
    /// - Throws: An error from EpubDataContainerError enum.
    func data(relativePath: String) throws -> Data

    /// Get the size of an asset in the container.
    ///
    /// - Parameter relativePath: The relative path to the asset.
    /// - Returns: The size of the asset.
    /// - Throws: An error from EpubDataContainerError enum.
    func dataLength(relativePath: String) throws -> UInt64

    /// Get an seekable input stream with the bytes of the asset in the container.
    ///
    /// - Parameter relativePath: The relative path to the asset.
    /// - Returns: A seekable input stream.
    /// - Throws: An error from EpubDataContainerError enum.
    func dataInputStream(relativePath: String) throws -> SeekableInputStream
}
