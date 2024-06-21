//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Bridge between a Content Protection technology and the Readium toolkit.
///
/// Its responsibilities are to:
/// - Unlock a publication by returning a customized `Fetcher`.
/// - Create a `ContentProtectionService` publication service.
public protocol ContentProtection {
    /// Attempts to unlock a potentially protected publication asset.
    ///
    /// The Streamer will create a leaf `fetcher` for the low-level `asset` access (e.g.
    /// `ArchiveFetcher` for a ZIP archive), to avoid having each Content Protection open the asset
    /// to check if it's protected or not.
    ///
    /// A publication might be protected in such a way that the asset format can't be recognized,
    /// in which case the Content Protection will have the responsibility of creating a new leaf
    /// `Fetcher`.
    ///
    /// - Returns: A `ProtectedAsset` in case of success, nil if the asset is not protected by this
    ///   technology or a `Publication.OpeningError` if the asset can't be successfully opened, even
    ///   in restricted mode.
    func open(
        asset: Asset,
        credentials: String?,
        allowUserInteraction: Bool,
        sender: Any?
    ) async -> Result<ContentProtectionAsset, ContentProtectionOpenError>
}

public enum ContentProtectionOpenError: Error {
    /// The asset is not supported by this ``ContentProtection``
    case assetNotSupported(Error?)

    /// An error occurred while reading the asset.
    case reading(ReadError)
}

/// Represents a specific Content Protection technology, uniquely identified
/// with an HTTP URL.
public struct ContentProtectionScheme: RawRepresentable {
    public let rawValue: HTTPURL

    public init(rawValue: HTTPURL) {
        self.rawValue = rawValue
    }

    /// Readium LCP DRM scheme.
    public static let lcp = ContentProtectionScheme(rawValue: HTTPURL(string: "http://readium.org/2014/01/lcp")!)

    /// Adobe ADEPT DRM scheme.
    public static let adept = ContentProtectionScheme(rawValue: HTTPURL(string: "http://ns.adobe.com/adept")!)
}

public struct ContentProtectionSchemeNotSupportedError: Error {
    public let scheme: ContentProtectionScheme

    public init(scheme: ContentProtectionScheme) {
        self.scheme = scheme
    }
}

/// Holds the result of opening an ``Asset`` with a ``ContentProtection``.
public struct ContentProtectionAsset {
    /// Asset granting access to the decrypted content.
    public let asset: Asset

    /// Transform which will be applied on the Publication Builder before creating the Publication.
    ///
    /// Can be used to add a Content Protection Service to the Publication that will be created by
    /// the Streamer.
    public let onCreatePublication: Publication.Builder.Transform?

    public init(asset: Asset, onCreatePublication: Publication.Builder.Transform? = nil) {
        self.asset = asset
        self.onCreatePublication = onCreatePublication
    }
}
