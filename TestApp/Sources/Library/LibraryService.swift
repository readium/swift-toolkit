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
    func confirmImportingDuplicatePublication(withTitle title: String) async -> Bool
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
    func openBook(_ book: Book, forPresentation prepareForPresentation: Bool, sender: UIViewController) async throws -> Publication {
        let (pub, _) = try await openPublication(at: book.url(), allowUserInteraction: true, sender: sender)
        try checkIsReadable(publication: pub)
        preparePresentation(of: pub, book: book)
        return pub
    }
    
    /// Opens the Readium 2 Publication at the given `url`.
    private func openPublication(at url: URL, allowUserInteraction: Bool, sender: UIViewController?) async throws -> (Publication, MediaType) {
        let asset = FileAsset(url: url)
        guard let mediaType = asset.mediaType() else {
            throw LibraryError.openFailed(Publication.OpeningError.unsupportedFormat)
        }
        
        return try await withCheckedThrowingContinuation { cont in
            streamer.open(asset: asset, allowUserInteraction: allowUserInteraction, sender: sender) { result in
                switch result {
                case .success(let publication):
                    cont.resume(returning: (publication, mediaType))
                case .failure(let error):
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
    func importPublications(from sourceURLs: [URL], sender: UIViewController) async throws {
        for url in sourceURLs {
            try await importPublication(from: url, sender: sender)
        }
    }
    
    /// Imports the publication at the given `url` to the bookshelf.
    ///
    /// If the `url` is a local file URL, the publication is copied to Documents/. For a remote URL,
    /// it is first downloaded.
    ///
    /// DRM services are used to fulfill the publication, in case the URL locates a licensing
    /// document.
    @discardableResult
    func importPublication(from sourceURL: URL, sender: UIViewController, progress: @escaping (Double) -> Void = { _ in }) async throws -> Book {
        var url = try await downloadIfNeeded(sourceURL, progress: progress)
        url = try await fulfillIfNeeded(url)
        let (pub, mediaType) = try await openPublication(at: url, allowUserInteraction: false, sender: sender)
        let coverPath = try importCover(of: pub)
        url = try moveToDocuments(from: url, title: pub.metadata.title, mediaType: mediaType)
        return try await insertBook(at: url, publication: pub, mediaType: mediaType, coverPath: coverPath)
    }
    
    /// Downloads `sourceURL` if it locates a remote file.
    private func downloadIfNeeded(_ url: URL, progress: @escaping (Double) -> Void) async throws -> URL {
        guard !url.isFileURL, url.scheme != nil else {
            return url
        }
        
        do {
            return try await httpClient.download(url, progress: progress).file
        } catch {
            throw LibraryError.downloadFailed(error)
        }
    }
    
    /// Fulfills the given `url` if it's a DRM license file.
    private func fulfillIfNeeded(_ url: URL) async throws -> URL {
        guard let drmService = drmLibraryServices.first(where: { $0.canFulfill(url) }) else {
            return url
        }
        
        do {
            let pub = try await drmService.fulfill(url)
            guard let url = pub?.localURL else {
                throw LibraryError.cancelled
            }
            return url
        } catch {
            throw LibraryError.downloadFailed(error)
        }
    }
    
    /// Moves the given `sourceURL` to the user Documents/ directory.
    private func moveToDocuments(from source: URL, title: String, mediaType: MediaType) throws -> URL {
        let destination = Paths.makeDocumentURL(title: title, mediaType: mediaType)
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
            return destination
        } catch {
            throw LibraryError.importFailed(error)
        }
    }
    
    /// Imports the publication cover and return its path relative to the Covers/ folder.
    private func importCover(of publication: Publication) throws -> String? {
        guard let cover = publication.cover?.pngData() else {
            return nil
        }
        let coverURL = Paths.covers.appendingUniquePathComponent()
        
        do {
            try cover.write(to: coverURL)
            return coverURL.lastPathComponent
        } catch {
            throw LibraryError.importFailed(error)
        }
    }
    
    /// Inserts the given `book` in the bookshelf.
    private func insertBook(at url: URL, publication: Publication, mediaType: MediaType, coverPath: String?) async throws -> Book {
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
        
        do {
            try await books.add(book)
            return book
        } catch {
            throw LibraryError.importFailed(error)
        }
    }
    
    private func confirmImportingDuplicate(book: Book) async throws {
        guard let delegate = delegate else {
            return
        }
        
        let confirmed = await delegate.confirmImportingDuplicatePublication(withTitle: book.title)
        guard confirmed else {
            throw LibraryError.cancelled
        }
    }
    
    
    // MARK: Removing

    func remove(_ book: Book) async throws {
        guard let id = book.id else {
            throw LibraryError.bookDeletionFailed(nil)
        }
        
        // FIXME: ?
        publicationServer.remove(at: book.path)
        
        do {
            try await books.remove(id)
            try removeBookFile(at: book.url())
        } catch {
            throw LibraryError.bookDeletionFailed(error)
        }
    }
        
    private func removeBookFile(at url: URL) throws {
        guard Paths.documents.isParentOf(url) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw LibraryError.bookDeletionFailed(error)
        }
    }
}


private extension Book {
    
    func url() throws -> URL {
        // Absolute URL.
        if let url = URL(string: path), url.scheme != nil {
            return url
        }
        
        // Absolute file path.
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        
        do {
            // Path relative to Documents/.
            let files = FileManager.default
            let documents = try files.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

            let documentURL = documents.appendingPathComponent(path)
            guard (try? documentURL.checkResourceIsReachable()) == true else {
                throw LibraryError.bookNotFound
            }
            return documentURL

        } catch {
            throw LibraryError.bookNotFound
        }
    }
}
