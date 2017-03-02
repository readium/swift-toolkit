//
//  EpubFetcher.swift
//  R2Streamer
//
//  Created by Olivier Körner on 21/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation

/// Error throw by the `EpubFetcher`.
///
/// - missingFile: The file is missing from the container.
/// - container: An Container error occurred.
/// - missingRootFile: The rootFile is missing from internalData
public enum EpubFetcherError: Error {
    case missingFile(path: String)

    /// An Container error occurred, **underlyingError** thrown.
    case container(underlyingError: Error)

    /// No rootFile in internalData, unable to get path to publication
    case missingRootFile()
}

/// A EpubFetcher object lets you get the data from the assets in the EPUB
/// container. It will fetch the data in the container and apply content filters
/// (decryption for example).
internal class EpubFetcher {
    
    /// The publication to fetch from
    internal let publication: Publication
    
    /// The container to access the resources from
    internal let container: Container
    
    /// The relative path to the directory holding the resources in the container
    internal let rootFileDirectory: String
    
    // TODO: Content filters
    //var contentFilters: [ContentFilter]

    // MARK: - Internal methods

    internal init(publication: Publication, container: Container) throws {
        self.container = container
        self.publication = publication
        
        // Get the path of the directory of the rootFile, to access resources
        // relative to the rootFile
        guard let rootfilePath = publication.internalData["rootfile"] as NSString? else {
            throw EpubFetcherError.missingRootFile()
        }
        rootFileDirectory = rootfilePath.deletingLastPathComponent
    }

    /// Gets all the data from an resource file in a publication's container.
    ///
    /// - Parameter path: The relative path to the asset in the publication.
    /// - Returns: The decrypted data of the asset.
    /// - Throws: `EpubFetcherError.missingFile`.
    internal func data(forRelativePath path: String) throws -> Data? {
        // Build the path relative to the container
        let pubRelativePath = rootFileDirectory.appending(pathComponent: path)

        // Get the link information from the publication
        guard let _ = publication.resource(withRelativePath: path) else {
            throw EpubFetcherError.missingFile(path: path)
        }
        // Get the data from the container
        guard let data = try? container.data(relativePath: pubRelativePath) else {
            throw EpubFetcherError.missingFile(path: pubRelativePath)
        }
        // TODO: content filters
        return data
    }

    /// Get the total length of the data in an resource file.
    ///
    /// - Parameter path: The relative path to the asset in the publication.
    /// - Returns: The length of the data.
    /// - Throws: `EpubFetcherError.missingFile`.
    internal func dataLength(forRelativePath path: String) throws -> UInt64 {
        // Build the path relative to the container
        let pubRelativePath = rootFileDirectory.appending(pathComponent: path)

        // Get the link information from the publication
        guard let _ = publication.resource(withRelativePath: path) else {
            throw EpubFetcherError.missingFile(path: path)
        }
        // Get the data length from the container
        guard let length = try? container.dataLength(relativePath: pubRelativePath) else {
            throw EpubFetcherError.missingFile(path: pubRelativePath)
        }
        return length
    }

    /// Get an input stream with the data of the resource.
    ///
    /// - Parameter path: The relative path to the asset in the publication.
    /// - Returns: A seekable input stream with the decrypted data if the resource.
    /// - Throws: `EpubFetcherError.missingFile`.
    internal func dataStream(forRelativePath path: String) throws -> SeekableInputStream {
        // Build the path relative to the container
        let pubRelativePath = rootFileDirectory.appending(pathComponent: path)

        // Get the link information from the publication
        guard let _ = publication.resource(withRelativePath: path) else {
            throw EpubFetcherError.missingFile(path: path)
        }
        // Get an input stream from the container
        let inputStream: SeekableInputStream

        do {
            inputStream = try container.dataInputStream(relativePath: pubRelativePath)
        } catch {
            throw EpubFetcherError.container(underlyingError: error)
        }
        // TODO: content filters
        return inputStream
    }
}
