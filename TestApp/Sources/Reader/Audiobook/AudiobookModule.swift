//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumNavigator
import ReadiumShared
import UIKit

final class AudiobookModule: ReaderFormatModule {
    weak var delegate: ReaderFormatModuleDelegate?

    init(delegate: ReaderFormatModuleDelegate?) {
        self.delegate = delegate
    }

    func supports(_ publication: Publication) -> Bool {
        publication.conforms(to: .audiobook)
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
        let preferencesStore = makePreferencesStore(books: books)
        let viewController = try await AudiobookViewController(
            publication: publication,
            locator: locator,
            bookId: bookId,
            books: books,
            bookmarks: bookmarks,
            initialPreferences: preferencesStore.preferences(for: bookId),
            preferencesStore: preferencesStore
        )
        viewController.moduleDelegate = delegate
        return viewController
    }

    func makePreferencesStore(books: BookRepository) -> AnyUserPreferencesStore<AudioPreferences> {
        CompositeUserPreferencesStore(
            publicationStore: DatabaseUserPreferencesStore(books: books),
            sharedStore: UserDefaultsUserPreferencesStore(),
            publicationFilter: { $0.filterPublicationPreferences() },
            sharedFilter: { $0.filterSharedPreferences() }
        ).eraseToAnyPreferencesStore()
    }
}
