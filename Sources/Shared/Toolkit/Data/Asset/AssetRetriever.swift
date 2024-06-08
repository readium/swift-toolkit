//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Retrieves an ``Asset`` instance that provides read-only access to the
/// resource(s) of an asset stored at a given ``AbsoluteURL`` and its
/// ``Format``.
public final class AssetRetriever {
    
    /// Retrieves an asset from a URL and a known format.
    public func retrieve(url: AbsoluteURL, format: Format) async -> Result<Asset, AssetRetrieveURLError> {
        fatalError()
    }
    
    /// Retrieves an asset from a URL and a known media type.
    public func retrieve(url: AbsoluteURL, mediaType: MediaType) async -> Result<Asset, AssetRetrieveURLError> {
        await retrieve(url: url, hints: FormatHints(mediaType: mediaType))
    }
    
    /// Retrieves an asset from a URL of unknown format.
    public func retrieve(url: AbsoluteURL, hints: FormatHints = FormatHints()) async -> Result<Asset, AssetRetrieveURLError> {
        fatalError()
    }
    
    /// Retrieves an asset from an already opened resource.
    public func retrieve(resource: Resource, hints: FormatHints = FormatHints()) async -> Result<Asset, AssetRetrieveError> {
        fatalError()
    }
    
    /// Retrieves an asset from an already opened container.
    public func retrieve(container: Container, hints: FormatHints = FormatHints()) async -> Result<Asset, AssetRetrieveError> {
        fatalError()
    }
    
    /// Sniffs the format of the content available at `url`.
    public func sniffFormat(url: AbsoluteURL, hints: FormatHints = FormatHints()) async -> Result<Format, AssetRetrieveURLError> {
        await retrieve(url: url, hints: hints)
            .map { $0.format }
    }
    
    /// Sniffs the format of a `Resource`.
    public func sniffFormat(resource: Resource, hints: FormatHints = FormatHints()) async -> Result<Format, AssetRetrieveError> {
        await retrieve(resource: resource, hints: hints)
            .map { $0.format }
    }
    
    /// Sniffs the format of a `Container`.
    public func sniffFormat(container: Container, hints: FormatHints = FormatHints()) async -> Result<Format, AssetRetrieveError> {
        await retrieve(container: container, hints: hints)
            .map { $0.format }
    }
}

/// Error while trying to retrieve an asset from a ``Resource`` or a
/// ``Container``.
public enum AssetRetrieveError: Error {
    
    /// The format of the resource is not recognized.
    case formatNotSupported
    
    /// An error occurred when trying to read the asset.
    case reading(ReadError)
}

/// Error while trying to retrieve an asset from an URL.
public enum AssetRetrieveURLError: Error {
    
    /// The scheme (e.g. http, file, content) for the requested URL is not
    /// supported.
    case schemeNotSupported(URLScheme)
    
    /// The format of the resource at the requested URL is not recognized.
    case formatNotSupported
    
    /// An error occurred when trying to read the asset.
    case reading(ReadError)
}
