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

enum BookImporterError: Error {
    case unknown
}

actor BookImporter: ObservableObject, Loggable {
    private let readerDependencies: ReaderDependencies
    private var subscriptions = Set<AnyCancellable>()
    
    init(readerDependencies: ReaderDependencies) {
        self.readerDependencies = readerDependencies
    }
    
    /// Imports the publication at the given `url` to the bookshelf.
    ///
    /// If the `url` is a local file URL, the publication is copied to Documents/. For a remote URL,
    /// it is first downloaded.
    ///
    /// DRM services are used to fulfill the publication, in case the URL locates a licensing
    /// document.
    func importPublication(from sourceURL: URL, progress: @escaping (Double) -> Void = { _ in }) async -> Result<Book, LibraryError> {
        let downloadResult = await downloadIfNeeded(sourceURL, progress: progress)
        switch downloadResult {
        case .success(let url):
            let fullfillResult = await fulfillIfNeeded(url)
            let opener = BookOpener(readerDependencies: self.readerDependencies)
            switch fullfillResult {
            case .success(let url):
                let openResult = await opener.openPublication(at: url, allowUserInteraction: false)
                switch openResult {
                case .success(let (pub, mediaType)):
                    do {
                        let coverPath = try await importCover(of: pub)
                        let docsURL = try await moveToDocuments(from: url, title: pub.metadata.title, mediaType: mediaType)
                        let book = try await insertBook(at: docsURL, publication: pub, mediaType: mediaType, coverPath: coverPath)
                        return .success(book)
                    } catch {
                        if let libraryError = error as? LibraryError {
                            return .failure(libraryError)
                        }
                        return .failure(LibraryError.unknown)
                    }
                case .failure(let libraryError):
                    return .failure(libraryError)
                }
            case .failure(let libraryError):
                return .failure(libraryError)
            }
        case .failure(let libraryError):
            return .failure(libraryError)
        }
    }
    
    /// Downloads `sourceURL` if it locates a remote file.
    private func downloadIfNeeded(_ url: URL, progress: @escaping (Double) -> Void) async -> Result<URL, LibraryError> {
        await withCheckedContinuation({ continuation in
            guard !url.isFileURL, url.scheme != nil else {
                return continuation.resume(returning: .success(url))
            }
            
            readerDependencies.httpClient.download(url, progress: progress)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let httpError):
                        continuation.resume(
                            returning: .failure(
                                LibraryError.downloadFailed(httpError)
                            )
                        )
                    case .finished:
                        break
                    }
                }, receiveValue: { download in
                    continuation.resume(returning: .success(download.file))
                })
                .store(in: &subscriptions)
        })
    }
    
    /// Imports the publication cover and return its path relative to the Covers/ folder.
    /// throws - LibraryErrror
    private func importCover(of publication: Publication) async throws -> String? {
        guard let cover = publication.cover?.pngData() else {
            return nil
        }
        let coverURL = Paths.covers.appendingUniquePathComponent()
        
        do {
            try cover.write(to: coverURL)
            return coverURL.lastPathComponent
        } catch {
            print(coverURL)
            print(error)
            throw LibraryError.importFailed(error)
        }
    }
    
    /// Moves the given `sourceURL` to the user Documents/ directory.
    /// throws - LibraryErrror
    private func moveToDocuments(from source: URL, title: String, mediaType: MediaType) async throws -> URL {
        let destination = await Paths.makeDocumentURL(title: title, mediaType: mediaType)
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
    
    /// Fulfills the given `url` if it's a DRM license file.
    private func fulfillIfNeeded(_ url: URL) async -> Result<URL, LibraryError> {
        await withCheckedContinuation({ continuation in
            guard let drmService = readerDependencies.drmLibraryServices.first(where: { $0.canFulfill(url) }) else {
                return continuation.resume(returning: .success(url))
            }
            
            drmService.fulfill(url)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(
                            returning: .failure(
                                LibraryError.downloadFailed(error)
                            )
                        )
                    }
                }, receiveValue: { publication in
                    guard let url = publication?.localURL else {
                        return continuation.resume(returning: .failure(LibraryError.cancelled))
                    }
                    continuation.resume(returning: .success(url))
                })
                .store(in: &subscriptions)
        })
    }
    
    /// Inserts the given `book` in the bookshelf.
    /// throws - LibraryErrror
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

        return try await withCheckedThrowingContinuation({ continuation in
            readerDependencies.books.add(book)
                .sink { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: LibraryError.importFailed(error))
                    }
                } receiveValue: { _ in
                    continuation.resume(returning: book)
                }
                .store(in: &subscriptions)
        })
    }
}

// TODO: confirmImportingDuplicate / confirmImportingDuplicatePublication
