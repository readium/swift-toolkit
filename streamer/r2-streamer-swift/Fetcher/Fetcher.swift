//
//  EpubFetcher.swift
//  r2-streamer-swift
//
//  Created by Olivier Körner on 21/12/2016.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

/// Error throw by the `Fetcher`.
///
/// - missingFile: The file is missing from the container.
/// - container: An Container error occurred.
public enum FetcherError: Error {
    case missingFile(path: String)
    /// An Container error occurred, **underlyingError** thrown.
    case container(underlyingError: Error)
    /// The mimetype of the container is empty.
    case missingContainerMimetype
    /// The link href couldn't be found in the container.
    case linkNotFound
}

/// The Fetcher object lets you get the data from the assets in the container.
/// It will fetch the data in the container and apply content filters
/// (decryption for example).

// Default implementation.
internal class Fetcher: Loggable {
    /// The publication.
    let publication: Publication
    /// The container to fetch resources from.
    let container: Container
    /// The relative path to the directory holding the resources in the container.
    let rootFileDirectory: String
    /// The content filter.
    let contentFilters: ContentFilters?

    internal init(publication: Publication, container: Container) throws {
        self.container = container
        self.publication = publication

        // Get the path of the directory of the rootFile, to access resources
        // relative to the rootFile
        let rootfilePath = container.rootFile.rootFilePath

        if !rootfilePath.isEmpty, rootfilePath.contains("/") {
            rootFileDirectory = rootfilePath.deletingLastPathComponent
        } else {
            rootFileDirectory = ""
        }
        contentFilters = Fetcher.getContentFilters(forMimeType: container.rootFile.mimetype)
    }

    /// Gets the data from an resource file in a publication's container.
    ///
    /// - Parameter path: The relative path to the asset in the publication.
    /// - Returns: The decrypted data of the asset.
    /// - Throws: `EpubFetcherError.missingFile`.
    internal func data(forRelativePath path: String) throws -> Data? {
        // Get the link information from the publication
        guard publication.resource(withHref: path) != nil else {
            throw FetcherError.missingFile(path: path)
        }
        // Get the data from the container
        var data = try container.data(relativePath: path)
        if let contentFilters = contentFilters {
            data = try contentFilters.apply(to: data, of: publication, with: container, at: path)
        }
        return data
    }

    internal func data(forLink link: Link) throws -> Data? {
        let path = link.href
        var data = try container.data(relativePath: path)
        if let contentFilters = contentFilters {
            data = try contentFilters.apply(to: data, of: publication, with: container, at: path)
        }
        return data
    }

    /// Get an input stream with the data of the resource.
    ///
    /// - Parameter path: The relative path to the asset in the publication.
    /// - Returns: A seekable input stream with the decrypted data if the resource.
    /// - Throws: `EpubFetcherError.missingFile`.
    internal func dataStream(forRelativePath path: String) throws -> SeekableInputStream {
        var inputStream: SeekableInputStream

        // Get the link information from the publication
        guard let _ = publication.resource(withHref: path) else {
            throw FetcherError.missingFile(path: path)
        }
        // Get an input stream from the container
        inputStream = try container.dataInputStream(relativePath: path)
        // Apply content filters to inputStream data.
        if let contentFilters = contentFilters {
            inputStream = try contentFilters.apply(to: inputStream, of: publication, with: container, at: path)
        }

        return inputStream
    }

    internal func dataStream(forLink link: Link) throws -> SeekableInputStream? {
        var inputStream: SeekableInputStream
        let path = link.href
        // Get an input stream from the container
        inputStream = try container.dataInputStream(relativePath: path)
        // Apply content filters to inputStream data.
        if let contentFilters = contentFilters {
            inputStream = try contentFilters.apply(to: inputStream, of: publication, with: container, at: path)
        }

        return inputStream
    }

    /// Get the total length of the data in a resource file.
    ///
    /// - Parameter path: The relative path to the asset in the publication.
    /// - Returns: The length of the data.
    /// - Throws: `EpubFetcherError.missingFile`.
    internal func dataLength(forRelativePath path: String) throws -> UInt64 {
        // Build the path relative to the container
        let relativePath = rootFileDirectory.appending(pathComponent: path)

        // Get the link information from the publication
        guard let _ = publication.resource(withHref: path) else {
            throw FetcherError.missingFile(path: path)
        }
        // Get the data length from the container
        guard let length = try? container.dataLength(relativePath: relativePath) else {
            throw FetcherError.missingFile(path: relativePath)
        }
        return length
    }

    /// Return the right ContentFilter subclass instance depending of the mime
    /// type.
    ///
    /// - Parameter mimeType: The mimetype string.
    /// - Returns: The corresponding ContentFilters subclass.
    static func getContentFilters(forMimeType mediaType: String?) -> ContentFilters? {
        guard let format = Format.of(mediaType: mediaType) else {
            log(.error, "Format can't be detected from: \(String(describing: mediaType))")
            return nil
        }
        
        switch format {
        case .epub:
            return ContentFiltersEpub()
        case .cbz:
            return ContentFiltersCbz()
        case .lcpProtectedPDF, .lcpProtectedAudiobook:
            return ContentFiltersLCP()
        default:
            return nil
        }
    }
}
