//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a digital medium (e.g. a file) offering access to a publication.
public protocol PublicationAsset {
    
    /// Name of the asset, e.g. a filename.
    var name: String { get }
    
    /// Resolves the media type of the asset.
    ///
    /// *Warning*: This should not be called from the UI thread.
    func mediaType() -> MediaType?
    
    /// Creates a fetcher used to access the asset's content.
    func makeFetcher(using dependencies: PublicationAssetDependencies, credentials: String?, completion: @escaping (CancellableResult<Fetcher, Publication.OpeningError>) -> Void) -> Void
    
}

public struct PublicationAssetDependencies {
    public let archiveFactory: ArchiveFactory
    
    public init(archiveFactory: ArchiveFactory) {
        self.archiveFactory = archiveFactory
    }
    
}
