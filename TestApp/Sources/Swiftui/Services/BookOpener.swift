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
        await withCheckedContinuation { continuation in
            book.url()
                .flatMap {
                    self.openPublication(at: $0, allowUserInteraction: true)
                }
                .flatMap {
                    (pub, _) in self.checkIsReadable(publication: pub)
                }
                .handleEvents(receiveOutput: {
                    self.preparePresentation(of: $0, book: book)
                })
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    if case .failure(let error) = completion {
                        // TODO: map "error" into "BookOpenerError"
                        continuation.resume(returning: .failure(BookOpenerError.unknown))
                    }
                } receiveValue: { publication in
                    continuation.resume(returning: .success(publication))
                }.store(in: &subscriptions)
        }
    }
    
    /// Opens the Readium 2 Publication at the given `url`.
    private func openPublication(at url: URL, allowUserInteraction: Bool) -> AnyPublisher<(Publication, MediaType), LibraryError> {
        Future(on: .global()) { promise in
            let asset = FileAsset(url: url)
            guard let mediaType = asset.mediaType() else {
                promise(.failure(.openFailed(Publication.OpeningError.unsupportedFormat)))
                return
            }
            
            self.streamer.open(asset: asset, allowUserInteraction: allowUserInteraction) { result in
                switch result {
                case .success(let publication):
                    promise(.success((publication, mediaType)))
                case .failure(let error):
                    promise(.failure(.openFailed(error)))
                case .cancelled:
                    promise(.failure(.cancelled))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    private func preparePresentation(of publication: Publication, book: Book) {
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
    private func checkIsReadable(publication: Publication) -> AnyPublisher<Publication, LibraryError> {
        guard !publication.isRestricted else {
            if let error = publication.protectionError {
                return .fail(.openFailed(error))
            } else {
                return .fail(.cancelled)
            }
        }
        return .just(publication)
    }
}

// MARK: - Helpers
private extension Book {
    
    func url() -> AnyPublisher<URL, LibraryError> {
        // Absolute URL.
        if let url = URL(string: path), url.scheme != nil {
            return .just(url)
        }
        
        // Absolute file path.
        if path.hasPrefix("/") {
            return .just(URL(fileURLWithPath: path))
        }
        
        return Future(on: .global()) { promise in
            do {
                // Path relative to Documents/.
                let files = FileManager.default
                let documents = try files.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

                let documentURL = documents.appendingPathComponent(path)
                if (try? documentURL.checkResourceIsReachable()) == true {
                    return promise(.success(documentURL))
                }
        
                promise(.failure(LibraryError.bookNotFound))

            } catch {
                promise(.failure(LibraryError.bookNotFound))
            }
        }.eraseToAnyPublisher()
    }
}
