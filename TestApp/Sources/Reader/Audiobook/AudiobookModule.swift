//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Navigator
import R2Shared
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
        highlights: HighlightRepository
    ) async throws -> UIViewController {
        guard publication.metadata.identifier != nil else {
            throw ReaderError.epubNotValid
        }

        let viewController = AudiobookViewController(
            publication: publication,
            locator: locator,
            bookId: bookId,
            books: books,
            bookmarks: bookmarks
        )
        viewController.moduleDelegate = delegate
        return viewController
    }
}
