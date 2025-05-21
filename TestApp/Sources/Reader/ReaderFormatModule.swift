//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import ReadiumShared
import UIKit

/// A ReaderFormatModule is a sub-module of ReaderModule that handles publication of a given format (eg. EPUB, CBZ).
protocol ReaderFormatModule {
    var delegate: ReaderFormatModuleDelegate? { get }

    /// Returns whether the given publication is supported by this module.
    func supports(_ publication: Publication) -> Bool

    /// Creates the view controller to present the publication.
    func makeReaderViewController(
        for publication: Publication,
        locator: Locator?,
        bookId: Book.Id,
        books: BookRepository,
        bookmarks: BookmarkRepository,
        highlights: HighlightRepository,
        readium: Readium
    ) async throws -> UIViewController
}

protocol ReaderFormatModuleDelegate: AnyObject {
    /// Shows the reader's outline from the given links.
    func presentOutline(of publication: Publication, bookId: Book.Id, from viewController: UIViewController) -> AnyPublisher<Locator, Never>

    /// Shows the DRM management screen for the given DRM.
    func presentDRM(for publication: Publication, from viewController: UIViewController)

    func presentAlert(_ title: String, message: String, from viewController: UIViewController)
    func presentError<T: UserErrorConvertible>(_ error: T, from viewController: UIViewController)
}
