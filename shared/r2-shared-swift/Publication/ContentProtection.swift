//
//  ContentProtection.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 14/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
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
        asset: PublicationAsset,
        fetcher: Fetcher,
        credentials: String?,
        allowUserInteraction: Bool,
        sender: Any?,
        completion: @escaping (CancellableResult<ProtectedAsset?, Publication.OpeningError>) -> Void
    )
    
}

/// Holds the result of opening a `PublicationAsset` with a `ContentProtection`.
public typealias ProtectedAsset = (
    
    /// Publication asset which will be provided to the parsers.
    ///
    /// In most cases, this will be the asset provided to `ContentProtection.open()`, but a Content
    /// Protection might modify it in some cases:
    /// - If the original asset has a media type that can't be recognized by parsers,
    ///   the Content Protection must return an asset with the matching unprotected media type.
    /// - If the Content Protection technology needs to redirect the Streamer to a different asset.
    ///   For example, this could be used to decrypt a publication to a temporary secure location.
    asset: PublicationAsset,

    /// Primary leaf fetcher to be used by parsers.
    ///
    /// The Content Protection can unlock resources by modifying the Fetcher provided to
    /// `ContentProtection.open()`, for example by:
    /// - Wrapping the given fetcher in a `TransformingFetcher` with a decryption
    ///   `ResourceTransformer` function.
    /// - Discarding the provided fetcher altogether and creating a new one to handle access
    ///   restrictions. For example, by creating an `HTTPFetcher` which will inject a Bearer Token
    ///   in requests.
    fetcher: Fetcher,

    /// Transform which will be applied on the Publication Builder before creating the Publication.
    ///
    /// Can be used to add a Content Protection Service to the Publication that will be created by
    /// the Streamer.
    onCreatePublication: Publication.Builder.Transform?
)
