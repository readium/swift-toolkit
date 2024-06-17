//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a publication stored as a file on the local file system.
public final class FileAsset: PublicationAsset, Loggable {
    /// File URL on the file system.
    public let file: FileURL

    private let mediaTypeHint: String?
    private let knownMediaType: MediaType?

    /// Creates a `File` from a file `url`.
    ///
    /// Providing a known `mediaType` will improve performances when sniffing the file format.
    public init(file: FileURL, mediaType: String? = nil) {
        self.file = file
        mediaTypeHint = mediaType
        knownMediaType = nil
    }

    /// Creates a `File` from a file `url`.
    ///
    /// Providing a known `mediaType` will improve performances when sniffing the file format.
    public init(file: FileURL, mediaType: MediaType?) {
        self.file = file
        mediaTypeHint = nil
        knownMediaType = mediaType
    }

    public var name: String { file.lastPathSegment }

    public func mediaType() -> MediaType? {
        warnIfMainThread()
        return resolvedMediaType
    }

    private lazy var resolvedMediaType: MediaType? =
        MediaType.of(file, mediaType: mediaTypeHint ?? knownMediaType?.string)

    public func makeFetcher(using dependencies: PublicationAssetDependencies, credentials: String?, completion: @escaping (CancellableResult<Fetcher, Publication.OpeningError>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            guard (try? self.file.exists()) == true else {
                completion(.failure(.notFound))
                return
            }

            do {
                // Attempts to open the file as a ZIP or exploded directory.
                let archive = try dependencies.archiveFactory.open(file: self.file, password: credentials).get()
                completion(.success(ArchiveFetcher(archive: archive)))

            } catch ArchiveError.invalidPassword {
                completion(.failure(.incorrectCredentials))

            } catch {
                // Falls back on serving the file as a single resource.
                let fileExtension = self.resolvedMediaType?.fileExtension?.addingPrefix(".") ?? ""
                let href = RelativeURL(path: "publication\(fileExtension)")!
                completion(.success(FileFetcher(href: href, file: self.file)))
            }
        }
    }
}

extension FileAsset: CustomStringConvertible {
    public var description: String {
        "FileAsset(\(file.path))"
    }
}
