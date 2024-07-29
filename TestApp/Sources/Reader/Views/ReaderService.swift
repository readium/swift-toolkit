//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer
import UIKit

typealias ReaderViewControllerType = UIViewController & Navigator

class ReaderService {
    let bookmarks: BookmarkRepository
    let highlights: HighlightRepository
    let makeReaderVCFunc: (Publication, Book, NavigatorDelegate) -> ReaderViewControllerType
    let drmLibraryServices: [DRMLibraryService]
    let streamer: Streamer
    let httpClient: HTTPClient
    
    init(bookmarks: BookmarkRepository,
         highlights: HighlightRepository,
         makeReaderVCFunc: @escaping (Publication, Book, NavigatorDelegate) -> ReaderViewControllerType,
         drmLibraryServices: [DRMLibraryService],
         streamer: Streamer,
         httpClient: HTTPClient
    ) {
        self.bookmarks = bookmarks
        self.highlights = highlights
        self.makeReaderVCFunc = makeReaderVCFunc
        self.drmLibraryServices = drmLibraryServices
        self.streamer = streamer
        self.httpClient = httpClient
    }
    
    func openBook(_ book: Book, sender: UIViewController) async throws -> Publication {
        let (pub, _) = try await openPublication(at: book.url(), allowUserInteraction: true, sender: sender)
        try checkIsReadable(publication: pub)
        return pub
    }

    /// Opens the Readium 2 Publication at the given `url`.
    private func openPublication(at url: FileURL, allowUserInteraction: Bool, sender: UIViewController?) async throws -> (Publication, MediaType) {
        let asset = FileAsset(file: url)
        guard let mediaType = asset.mediaType() else {
            throw LibraryError.openFailed(Publication.OpeningError.unsupportedFormat)
        }

        return try await withCheckedThrowingContinuation { cont in
            streamer.open(asset: asset, allowUserInteraction: allowUserInteraction, sender: sender) { result in
                switch result {
                case let .success(publication):
                    cont.resume(returning: (publication, mediaType))
                case let .failure(error):
                    cont.resume(throwing: LibraryError.openFailed(error))
                case .cancelled:
                    cont.resume(throwing: LibraryError.cancelled)
                }
            }
        }
    }

    /// Checks if the publication is not still locked by a DRM.
    private func checkIsReadable(publication: Publication) throws {
        guard !publication.isRestricted else {
            if let error = publication.protectionError {
                throw LibraryError.openFailed(error)
            } else {
                throw LibraryError.cancelled
            }
        }
    }
}

private extension Book {
    func url() throws -> FileURL {
        guard let url = AnyURL(string: path) else {
            throw LibraryError.bookNotFound
        }

        switch url {
        case let .absolute(url):
            guard let url = url.fileURL else {
                throw LibraryError.bookNotFound
            }
            return url

        case let .relative(relativeURL):
            // Path relative to Documents/.
            guard let url = Paths.documents.resolve(relativeURL) else {
                throw LibraryError.bookNotFound
            }
            return url
        }
    }
}
