//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import R2Navigator
import R2Shared
import R2Streamer
import ReadiumAdapterGCDWebServer
import UIKit

class CBZViewController: ReaderViewController<CBZNavigatorViewController> {
    init(publication: Publication, locator: Locator?, bookId: Book.Id, books: BookRepository, bookmarks: BookmarkRepository) throws {
        let navigator = try CBZNavigatorViewController(
            publication: publication,
            initialLocation: locator,
            httpServer: GCDHTTPServer.shared
        )

        super.init(navigator: navigator, publication: publication, bookId: bookId, books: books, bookmarks: bookmarks)

        navigator.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
    }

    override var currentBookmark: Bookmark? {
        guard let locator = navigator.currentLocation else {
            return nil
        }

        return Bookmark(bookId: bookId, locator: locator)
    }
}

extension CBZViewController: CBZNavigatorDelegate {}
