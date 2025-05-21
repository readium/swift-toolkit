//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumNavigator
import ReadiumShared
import UIKit

final class EPUBModule: ReaderFormatModule {
    weak var delegate: ReaderFormatModuleDelegate?

    init(delegate: ReaderFormatModuleDelegate?) {
        self.delegate = delegate
    }

    func supports(_ publication: Publication) -> Bool {
        publication.conforms(to: .epub) || publication.readingOrder.allAreHTML
    }

    @MainActor
    func makeReaderViewController(
        for publication: Publication,
        locator: Locator?,
        bookId: Book.Id,
        books: BookRepository,
        bookmarks: BookmarkRepository,
        highlights: HighlightRepository,
        readium: Readium
    ) async throws -> UIViewController {
        guard publication.metadata.identifier != nil else {
            throw ReaderError.epubNotValid
        }

        let preferencesStore = makePreferencesStore(books: books)
        let epubViewController = try await EPUBViewController(
            publication: publication,
            locator: locator,
            bookId: bookId,
            books: books,
            bookmarks: bookmarks,
            highlights: highlights,
            initialPreferences: preferencesStore.preferences(for: bookId),
            preferencesStore: preferencesStore,
            httpServer: readium.httpServer
        )
        epubViewController.moduleDelegate = delegate
        return epubViewController
    }

    func makePreferencesStore(books: BookRepository) -> AnyUserPreferencesStore<EPUBPreferences> {
        CompositeUserPreferencesStore(
            publicationStore: DatabaseUserPreferencesStore(books: books),
            sharedStore: UserDefaultsUserPreferencesStore(),
            publicationFilter: { $0.filterPublicationPreferences() },
            sharedFilter: { $0.filterSharedPreferences() }
        ).eraseToAnyPreferencesStore()
    }
}
