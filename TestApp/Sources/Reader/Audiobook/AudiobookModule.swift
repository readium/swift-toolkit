//
//  Copyright 2026 Readium Foundation. All rights reserved.
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
        let settingsStore = UserSettingsStore<AudioUserSettings>(books: books)
        let viewController = try await AudiobookViewController(
            publication: publication,
            locator: locator,
            bookId: bookId,
            books: books,
            bookmarks: bookmarks,
            initialPreferences: settingsStore.settings(for: bookId).preferences(),
            settingsStore: settingsStore
        )
        viewController.moduleDelegate = delegate
        return viewController
    }
}
