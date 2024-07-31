//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumAdapterGCDWebServer
import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer
import UIKit

typealias ReaderViewControllerType = Navigator & UIViewController

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
         httpClient: HTTPClient)
    {
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

    func makeReaderVCFunc(for publication: Publication, book: Book, delegate: NavigatorDelegate) -> ReaderViewControllerType {
        let locator = book.locator
        let httpServer = GCDHTTPServer.shared

        do {
            if publication.conforms(to: .pdf) {
                let navigator = try PDFNavigatorViewController(publication: publication, initialLocation: locator, httpServer: httpServer)
                navigator.delegate = delegate as? PDFNavigatorDelegate
                return navigator
            }

            if publication.conforms(to: .epub) || publication.readingOrder.allAreHTML {
                guard publication.metadata.identifier != nil else {
                    fatalError("ReaderError.epubNotValid")
                }

                let navigator = try EPUBNavigatorViewController(publication: publication, initialLocation: locator, httpServer: httpServer)
                navigator.delegate = delegate as? EPUBNavigatorDelegate
                return navigator
            }

            if publication.conforms(to: .divina) {
                let navigator = try CBZNavigatorViewController(publication: publication, initialLocation: locator, httpServer: httpServer)
                navigator.delegate = delegate as? CBZNavigatorDelegate
                return navigator
            }
        } catch {
            fatalError("Failed: \(error)")
        }
        return StubNavigatorViewController(coder: NSCoder())!
    }

    private class StubNavigatorViewController: UIViewController, Navigator {
        var publication: ReadiumShared.Publication

        var currentLocation: Locator?

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
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
