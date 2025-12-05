//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer
import UIKit

class CBZViewController: VisualReaderViewController<CBZNavigatorViewController> {
    init(
        publication: Publication,
        locator: Locator?,
        bookId: Book.Id,
        books: BookRepository,
        bookmarks: BookmarkRepository,
        httpServer: HTTPServer
    ) throws {
        let navigator = try CBZNavigatorViewController(
            publication: publication,
            initialLocation: locator,
            httpServer: httpServer
        )

        super.init(
            navigator: navigator,
            publication: publication,
            bookId: bookId,
            books: books,
            bookmarks: bookmarks,
            highlights: nil
        )

        navigator.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
    }
}

extension CBZViewController: CBZNavigatorDelegate {}
