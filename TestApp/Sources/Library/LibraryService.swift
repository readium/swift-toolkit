//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import ReadiumShared
import ReadiumStreamer
import UIKit

/// The Library service is used to:
///
/// - Import new publications (`Book` in the database).
/// - Remove existing publications from the bookshelf.
/// - Open publications for presentation in a navigator.
final class LibraryService: Loggable {
    private let books: BookRepository
    private let readium: Readium
    private let lcp: LCPModuleAPI

    init(books: BookRepository, readium: Readium, lcp: LCPModuleAPI) {
        self.books = books
        self.readium = readium
        self.lcp = lcp
    }

    func allBooks() -> AnyPublisher<[Book], Error> {
        books.all()
    }

    // MARK: Opening

    /// Opens the Readium 2 Publication for the given `book`.
    func openBook(_ book: Book, sender: UIViewController) async throws -> Publication? {
        let (pub, _) = try await openPublication(at: book.absoluteURL(), allowUserInteraction: true, sender: sender)
        guard try checkIsReadable(publication: pub) else {
            return nil
        }
        return pub
    }

    /// Opens the Readium 2 Publication at the given `url`.
    private func openPublication(
        at url: AbsoluteURL,
        allowUserInteraction: Bool,
        sender: UIViewController?
    ) async throws -> (Publication, Format) {
        do {
            let asset = try await readium.assetRetriever.retrieve(url: url).get()

            let publication = try await readium.publicationOpener.open(
                asset: asset,
                allowUserInteraction: allowUserInteraction,
                sender: sender
            ).get()

            return (publication, asset.format)

        } catch {
            throw LibraryError.openFailed(error)
        }
    }

    /// Checks if the publication is not still locked by a DRM.
    private func checkIsReadable(publication: Publication) throws -> Bool {
        guard !publication.isRestricted else {
            if let error = publication.protectionError {
                throw LibraryError.publicationIsRestricted(error)
            } else {
                return false
            }
        }

        return true
    }

    // MARK: Importation

    /// Imports a bunch of publications.
    func importPublications(from sourceURLs: [URL], sender: UIViewController) async throws {
        for url in sourceURLs {
            guard let url = url.anyURL.absoluteURL else {
                continue
            }
            try await importPublication(from: url, sender: sender, progress: { _ in })
        }
    }

    ///
    /// Imports the publication at the given `url` to the bookshelf.
    ///
    /// If the `url` is a local file URL, the publication is copied to
    /// Documents/ first.
    ///
    /// DRM services are used to fulfill the publication, in case the URL
    /// locates a licensing document.
    @discardableResult
    func importPublication(
        from url: AbsoluteURL,
        sender: UIViewController,
        progress: @escaping (Double) -> Void
    ) async throws -> Book {
        // Necessary to read URL exported from the Files app, for example.
        let shouldRelinquishAccess = url.url.startAccessingSecurityScopedResource()
        defer {
            if shouldRelinquishAccess {
                url.url.stopAccessingSecurityScopedResource()
            }
        }

        var url = url
        if let file = url.fileURL {
            url = try await fulfillIfNeeded(file, progress: progress)
        }

        let (pub, format) = try await openPublication(at: url, allowUserInteraction: false, sender: sender)
        let coverPath = try await importCover(of: pub)

        if let file = url.fileURL {
            url = try moveToDocuments(
                from: file,
                title: pub.metadata.title ?? file.lastPathSegment,
                format: format
            )
        }

        return try await insertBook(at: url, publication: pub, mediaType: format.mediaType, coverPath: coverPath)
    }

    /// Fulfills the given `url` if it's a DRM license file.
    private func fulfillIfNeeded(_ url: FileURL, progress: @escaping (Double) -> Void) async throws -> FileURL {
        guard lcp.canFulfill(url) else {
            return url
        }

        do {
            let pub = try await lcp.fulfill(url, progress: progress)
            return pub.localURL
        } catch {
            throw LibraryError.downloadFailed(error)
        }
    }

    /// Moves the given `sourceURL` to the user Documents/ directory.
    private func moveToDocuments(from source: FileURL, title: String, format: Format) throws -> FileURL {
        let destination = Paths.makeDocumentURL(title: title, format: format)

        do {
            // If the source file is part of the app folder, we can move it. Otherwise we make a
            // copy, to avoid deleting files from iCloud, for example.
            if Paths.isAppFile(at: source) {
                try FileManager.default.moveItem(at: source.url, to: destination.url)
            } else {
                try FileManager.default.copyItem(at: source.url, to: destination.url)
            }
            return destination
        } catch {
            throw LibraryError.importFailed(error)
        }
    }

    /// Imports the publication cover and return its path relative to the Covers/ folder.
    private func importCover(of publication: Publication) async throws -> String? {
        do {
            guard let cover = try await publication.cover().get()?.pngData() else {
                return nil
            }
            let coverURL = Paths.covers.appendingUniquePathComponent()

            try cover.write(to: coverURL.url)
            return coverURL.lastPathSegment
        } catch {
            throw LibraryError.importFailed(error)
        }
    }

    /// Inserts the given `book` in the bookshelf.
    private func insertBook(at url: AbsoluteURL, publication: Publication, mediaType: MediaType?, coverPath: String?) async throws -> Book {
        // Makes the URL relative to the Documents/ folder if possible.
        let url: AnyURL = Paths.documents.relativize(url)?.anyURL ?? url.anyURL

        let book = Book(
            identifier: publication.metadata.identifier,
            title: publication.metadata.title ?? url.lastPathSegment ?? "Untitled",
            authors: publication.metadata.authors
                .map(\.name)
                .joined(separator: ", "),
            type: mediaType?.string ?? MediaType.binary.string,
            url: url,
            coverPath: coverPath
        )

        do {
            try await books.add(book)
            return book
        } catch {
            throw LibraryError.importFailed(error)
        }
    }

    // MARK: Removing

    func remove(_ book: Book) async throws {
        guard let id = book.id else {
            throw LibraryError.bookDeletionFailed(nil)
        }

        do {
            try await books.remove(id)
            if let file = try book.absoluteURL().fileURL {
                try removeBookFile(at: file)
            }
        } catch {
            throw LibraryError.bookDeletionFailed(error)
        }
    }

    private func removeBookFile(at url: FileURL) throws {
        guard Paths.documents.isParent(of: url) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: url.url)
        } catch {
            throw LibraryError.bookDeletionFailed(error)
        }
    }
}

private extension Book {
    func absoluteURL() throws -> AbsoluteURL {
        guard let url = AnyURL(string: url) else {
            throw LibraryError.bookNotFound
        }

        switch url {
        case let .absolute(url):
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
