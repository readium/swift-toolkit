//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import R2Shared
import R2Streamer
import SwiftUI

enum BookOpenerError: Error {
    case libraryError(_ error: Error)
    case unknown
}

actor BookOpener: ObservableObject, Loggable {
    init(readerDependencies: ReaderDependencies) {
        self.readerDependencies = readerDependencies
        
        #if LCP
        drmLibraryServices.append(LCPLibraryService())
        #endif

        streamer = Streamer(
            contentProtections: drmLibraryServices.compactMap { $0.contentProtection }
        )
    }
    
// MARK: - Private Members
    private let readerDependencies: ReaderDependencies
    private var subscriptions = Set<AnyCancellable>()
    private var drmLibraryServices = [DRMLibraryService]()
    private let streamer: Streamer
    
// MARK: - Private Methods
    /// Opens the Readium 2 Publication for the given `book`.
    ///
    /// If the `Publication` is intended to be presented in a navigator, set `forPresentation`.
    func openBook(_ book: Book) async -> Result<Publication, BookOpenerError> {
        let bookURLResult = await book.url()
        switch bookURLResult {
        case .success(let url):
            let openPubResult = await openPublication(at: url, allowUserInteraction: true)
            switch openPubResult {
            case .success(let (pub1, _)):
                let checkReadableResult = await checkIsReadable(publication: pub1)
                switch checkReadableResult {
                case .success(let pub2):
                    await preparePresentation(of: pub2, book: book)
                    return .success(pub2)
                case .failure(let libraryError):
                    return .failure(BookOpenerError.libraryError(libraryError))
                }
            case .failure(let libraryError):
                return .failure(BookOpenerError.libraryError(libraryError))
            }
        case .failure(let libraryError):
            return .failure(BookOpenerError.libraryError(libraryError))
        }
    }
    
    /// Opens the Readium 2 Publication at the given `url`.
    func openPublication(at url: URL, allowUserInteraction: Bool) async -> Result<(Publication, MediaType), LibraryError> {
        let asset = FileAsset(url: url)
        guard let mediaType = asset.mediaType() else {
            return .failure(.openFailed(Publication.OpeningError.unsupportedFormat))
        }
        
        return await withCheckedContinuation { (continuation: CheckedContinuation<Result<(Publication, MediaType), LibraryError>, Never>) in
            self.streamer.open(asset: asset, allowUserInteraction: allowUserInteraction) { result in
                switch result {
                case .success(let publication):
                    continuation.resume(returning: .success((publication, mediaType)))
                case .failure(let error):
                    continuation.resume(returning: .failure(.openFailed(error)))
                case .cancelled:
                    continuation.resume(returning: .failure(.cancelled))
                }
            }
        }
    }
    
    private func preparePresentation(of publication: Publication, book: Book) async {
        // If the book is a web pub manifest, it means it is loaded remotely from a URL, and it
        // doesn't need to be added to the publication server.
        guard !book.mediaType.isRWPM else {
            return
        }
        
        readerDependencies.publicationServer.removeAll()
        do {
            try readerDependencies.publicationServer.add(publication)
        } catch {
            log(.error, error)
        }
    }
    
    /// Checks if the publication is not still locked by a DRM.
    private func checkIsReadable(publication: Publication) async -> Result<Publication, LibraryError> {
        guard !publication.isRestricted else {
            if let error = publication.protectionError {
                return .failure(.openFailed(error))
            } else {
                return .failure(.cancelled)
            }
        }
        return .success(publication)
    }
}

extension Book {
    func url() async -> Result<URL, LibraryError> {
        // Absolute URL.
        if let url = URL(string: path), url.scheme != nil {
            return .success(url)
        }
        
        // Absolute file path.
        if path.hasPrefix("/") {
            return .success(URL(fileURLWithPath: path))
        }
        
        do {
            // Path relative to Documents/.
            let files = FileManager.default
            let documents = try files.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

            let documentURL = documents.appendingPathComponent(path)
            if (try? documentURL.checkResourceIsReachable()) == true {
                return .success(documentURL)
            }
    
            return .failure(LibraryError.bookNotFound)

        } catch {
            return .failure(LibraryError.bookNotFound)
        }
    }
}
