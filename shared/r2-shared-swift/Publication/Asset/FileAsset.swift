//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a publication stored as a file on the local file system.
public final class FileAsset: PublicationAsset, Loggable {
    
    /// File URL on the file system.
    public let url: URL
    
    private let mediaTypeHint: String?
    private let knownFormat: Format?
    
    /// Creates a `File` from a file `url`.
    ///
    /// Providing a known `mediaType` will improve performances when sniffing the file format.
    public init(url: URL, mediaType: String? = nil) {
        self.url = url
        self.mediaTypeHint = mediaType
        self.knownFormat = nil
    }
    
    /// Creates a `File` from a file `url`.
    ///
    /// Providing a known `format` will improve performances when sniffing the file format.
    public init(url: URL, format: Format?) {
        self.url = url
        self.mediaTypeHint = nil
        self.knownFormat = format
    }
    
    public var name: String { url.lastPathComponent }
    
    public lazy var format: Format? = {
        warnIfMainThread()
        if let format = knownFormat {
            return format
        } else {
            return Format.of(url, mediaType: mediaTypeHint)
        }
    }()
    
    public func makeFetcher(using dependencies: PublicationAssetDependencies, credentials: String?, completion: @escaping (CancellableResult<Fetcher, Publication.OpeningError>) -> Void) {
        DispatchQueue.global(qos: .background).async { [self] in
            guard (try? url.checkResourceIsReachable()) == true else {
                completion(.failure(.notFound))
                return
            }
    
            do {
                // Attempts to open the file as a ZIP or exploded directory.
                let archive = try dependencies.archiveFactory.open(url: url, password: credentials)
                completion(.success(ArchiveFetcher(archive: archive)))
        
            } catch ArchiveError.invalidPassword {
                completion(.failure(.incorrectCredentials))
        
            } catch {
                // Falls back on serving the file as a single resource.
                completion(.success(FileFetcher(href: "/\(name)", path: url)))
            }
        }
    }
    
}

extension FileAsset: CustomStringConvertible {
    
    public var description: String {
        "FileAsset(\(url.path))"
    }
    
}


/// Represents a path on the file system.
///
/// Used to cache the `Format` to avoid computing it at different locations.
@available(*, unavailable, renamed: "FileAsset")
public typealias File = FileAsset
