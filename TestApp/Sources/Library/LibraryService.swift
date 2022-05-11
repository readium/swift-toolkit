//
//  LibraryService.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 20.02.19.
//
//  Copyright 2019 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Combine
import Foundation
import UIKit
import R2Shared
import R2Streamer


protocol LibraryServiceDelegate: AnyObject {
    func confirmImportingDuplicatePublication(withTitle title: String) -> AnyPublisher<Bool, Never>
}

/// The Library service is used to:
///
/// - Import new publications (`Book` in the database).
/// - Remove existing publications from the bookshelf.
/// - Open publications for presentation in a navigator.
final class LibraryService: Loggable {
    
    weak var delegate: LibraryServiceDelegate?
    
    private let streamer: Streamer
    private let books: BookRepository
    private let publicationServer: PublicationServer
    private let httpClient: HTTPClient
    private var drmLibraryServices = [DRMLibraryService]()
    
    init(books: BookRepository, publicationServer: PublicationServer, httpClient: HTTPClient) {
        self.books = books
        self.publicationServer = publicationServer
        self.httpClient = httpClient
        
        #if LCP
        drmLibraryServices.append(LCPLibraryService())
        #endif
        
        streamer = Streamer(
            contentProtections: drmLibraryServices.compactMap { $0.contentProtection }
        )
    }
    
    func allBooks() -> AnyPublisher<[Book], Error> {
        books.all()
    }
    
    
    // MARK: Opening

    /// Opens the Readium 2 Publication for the given `book`.
    ///
    /// If the `Publication` is intended to be presented in a navigator, set `forPresentation`.
    func openBook(_ book: Book, forPresentation prepareForPresentation: Bool, sender: UIViewController) -> AnyPublisher<Publication, LibraryError> {
        book.url()
            .flatMap { self.openPublication(at: $0, allowUserInteraction: true, sender: sender) }
            .flatMap { (pub, _) in self.checkIsReadable(publication: pub) }
            .handleEvents(receiveOutput: { self.preparePresentation(of: $0, book: book) })
            .eraseToAnyPublisher()
    }
    
    /// Opens the Readium 2 Publication at the given `url`.
    private func openPublication(at url: URL, allowUserInteraction: Bool, sender: UIViewController?) -> AnyPublisher<(Publication, MediaType), LibraryError> {
        Future(on: .global()) { promise in
            let asset = FileAsset(url: url)
            guard let mediaType = asset.mediaType() else {
                promise(.failure(.openFailed(Publication.OpeningError.unsupportedFormat)))
                return
            }
            
            self.streamer.open(asset: asset, allowUserInteraction: allowUserInteraction, sender: sender) { result in
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

    private func preparePresentation(of publication: Publication, book: Book) {
        // If the book is a web pub manifest, it means it is loaded remotely from a URL, and it
        // doesn't need to be added to the publication server.
        guard !book.mediaType.isRWPM else {
            return
        }
        
        publicationServer.removeAll()
        do {
            try publicationServer.add(publication)
        } catch {
            log(.error, error)
        }
    }

    
    // MARK: Importation
    
    /// Imports a bunch of publications.
    func importPublications(from sourceURLs: [URL], sender: UIViewController) -> AnyPublisher<Void, LibraryError> {
        sourceURLs.publisher
            .setFailureType(to: LibraryError.self)
            .flatMap {
                self.importPublication(from: $0, sender: sender)
                    .map { _ in }
            }
            .eraseToAnyPublisher()
    }
    
    /// Imports the publication at the given `url` to the bookshelf.
    ///
    /// If the `url` is a local file URL, the publication is copied to Documents/. For a remote URL,
    /// it is first downloaded.
    ///
    /// DRM services are used to fulfill the publication, in case the URL locates a licensing
    /// document.
    func importPublication(from sourceURL: URL, sender: UIViewController, progress: @escaping (Double) -> Void = { _ in }) -> AnyPublisher<Book, LibraryError> {
        downloadIfNeeded(sourceURL, progress: progress)
            .flatMap { self.fulfillIfNeeded($0) }
            .flatMap { url in
                self.openPublication(at: url, allowUserInteraction: false, sender: sender).flatMap { pub, mediaType in
                    self.importCover(of: pub).flatMap { coverPath in
                        self.moveToDocuments(from: url, title: pub.metadata.title, mediaType: mediaType).flatMap { url in
                            self.insertBook(at: url, publication: pub, mediaType: mediaType, coverPath: coverPath)
                        }
                    }
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Downloads `sourceURL` if it locates a remote file.
    private func downloadIfNeeded(_ url: URL, progress: @escaping (Double) -> Void) -> AnyPublisher<URL, LibraryError> {
        guard !url.isFileURL, url.scheme != nil else {
            return .just(url)
        }
        
        return httpClient.download(url, progress: progress)
            .map { $0.file }
            .mapError { .downloadFailed($0) }
            .eraseToAnyPublisher()
    }
    
    /// Fulfills the given `url` if it's a DRM license file.
    private func fulfillIfNeeded(_ url: URL) -> AnyPublisher<URL, LibraryError> {
        guard let drmService = drmLibraryServices.first(where: { $0.canFulfill(url) }) else {
            return .just(url)
        }
        
        return drmService.fulfill(url)
            .mapError { LibraryError.downloadFailed($0) }
            .flatMap { pub -> AnyPublisher<URL, LibraryError> in
                guard let url = pub?.localURL else {
                    return .fail(.cancelled)
                }
                return .just(url)
            }
            .eraseToAnyPublisher()
    }
    
    /// Moves the given `sourceURL` to the user Documents/ directory.
    private func moveToDocuments(from source: URL, title: String, mediaType: MediaType) -> AnyPublisher<URL, LibraryError> {
        Paths.makeDocumentURL(title: title, mediaType: mediaType)
            .flatMap { destination in
                Future(on: .global()) { promise in
                    // Necessary to read URL exported from the Files app, for example.
                    let shouldRelinquishAccess = source.startAccessingSecurityScopedResource()
                    defer {
                        if shouldRelinquishAccess {
                            source.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    do {
                        // If the source file is part of the app folder, we can move it. Otherwise we make a
                        // copy, to avoid deleting files from iCloud, for example.
                        if Paths.isAppFile(at: source) {
                            try FileManager.default.moveItem(at: source, to: destination)
                        } else {
                            try FileManager.default.copyItem(at: source, to: destination)
                        }
                        promise(.success(destination))
                    } catch {
                        promise(.failure(LibraryError.importFailed(error)))
                    }
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Imports the publication cover and return its path relative to the Covers/ folder.
    private func importCover(of publication: Publication) -> AnyPublisher<String?, LibraryError> {
        Future(on: .global()) { promise in
            guard let cover = publication.cover?.pngData() else {
                promise(.success(nil))
                return
            }
            let coverURL = Paths.covers.appendingUniquePathComponent()
            
            do {
                try cover.write(to: coverURL)
                promise(.success(coverURL.lastPathComponent))
            } catch {
                print(coverURL)
                print(error)
                promise(.failure(.importFailed(error)))
            }
            
        }.eraseToAnyPublisher()
    }
    
    /// Inserts the given `book` in the bookshelf.
    private func insertBook(at url: URL, publication: Publication, mediaType: MediaType, coverPath: String?) -> AnyPublisher<Book, LibraryError> {
        let book = Book(
            identifier: publication.metadata.identifier,
            title: publication.metadata.title,
            authors: publication.metadata.authors
                .map { $0.name }
                .joined(separator: ", "),
            type: mediaType.string,
            path: (url.isFileURL || url.scheme == nil) ? url.lastPathComponent : url.absoluteString,
            coverPath: coverPath
        )
        
        return books.add(book)
            .map { _ in book }
            .mapError { LibraryError.importFailed($0) }
            .eraseToAnyPublisher()
    }
    
    private func confirmImportingDuplicate(book: Book) -> AnyPublisher<Void, LibraryError> {
        guard let delegate = delegate else {
            return .just(())
        }
        
        return delegate.confirmImportingDuplicatePublication(withTitle: book.title)
            .setFailureType(to: LibraryError.self)
            .flatMap { confirmed -> AnyPublisher<Void, LibraryError> in
                if confirmed {
                    return .just(())
                } else {
                    return .fail(.cancelled)
                }
            }
            .eraseToAnyPublisher()
    }
    
    
    // MARK: Removing

    func remove(_ book: Book) -> AnyPublisher<Void, LibraryError> {
        guard let id = book.id else {
            return .fail(.bookDeletionFailed(nil))
        }
        
        // FIXME: ?
        publicationServer.remove(at: book.path)
        
        return books.remove(id)
            .mapError { LibraryError.bookDeletionFailed($0) }
            .flatMap { book.url() }
            .flatMap { self.removeBookFile(at: $0) }
            .eraseToAnyPublisher()
    }
        
    private func removeBookFile(at url: URL) -> AnyPublisher<Void, LibraryError> {
        Future(on: .global()) { promise in
            if Paths.documents.isParentOf(url) {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    promise(.failure(.bookDeletionFailed(error)))
                }
            }
            promise(.success(()))
        }.eraseToAnyPublisher()
    }
}


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
