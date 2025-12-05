//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import ReadiumShared
import UIKit

/// The ReaderModule handles the presentation of publications to be read by the user.
/// It contains sub-modules implementing ReaderFormatModule to handle each format of publication (eg. CBZ, EPUB).
protocol ReaderModuleAPI {
    var delegate: ReaderModuleDelegate? { get }

    /// Presents the given publication to the user, inside the given navigation controller.
    /// - Parameter completion: Called once the publication is presented, or if an error occured.
    func presentPublication(publication: Publication, book: Book, in navigationController: UINavigationController)
}

protocol ReaderModuleDelegate: ModuleDelegate {}

final class ReaderModule: ReaderModuleAPI {
    weak var delegate: ReaderModuleDelegate?
    private let books: BookRepository
    private let bookmarks: BookmarkRepository
    private let highlights: HighlightRepository
    private let readium: Readium

    /// Sub-modules to handle different publication formats (eg. EPUB, CBZ)
    var formatModules: [ReaderFormatModule] = []

    private let factory = ReaderFactory()

    init(
        delegate: ReaderModuleDelegate?,
        books: BookRepository,
        bookmarks: BookmarkRepository,
        highlights: HighlightRepository,
        readium: Readium
    ) {
        self.delegate = delegate
        self.books = books
        self.bookmarks = bookmarks
        self.highlights = highlights
        self.readium = readium

        formatModules = [
            AudiobookModule(delegate: self),
            CBZModule(delegate: self),
            EPUBModule(delegate: self),
            PDFModule(delegate: self),
        ]
    }

    func presentPublication(publication: Publication, book: Book, in navigationController: UINavigationController) {
        Task {
            guard let delegate = delegate, let bookId = book.id else {
                fatalError("Reader delegate not set")
            }

            @MainActor func present(_ viewController: UIViewController) {
                let backItem = UIBarButtonItem()
                backItem.title = ""
                viewController.navigationItem.backBarButtonItem = backItem
                viewController.hidesBottomBarWhenPushed = true
                navigationController.pushViewController(viewController, animated: true)
            }

            guard let module = self.formatModules.first(where: { $0.supports(publication) }) else {
                delegate.presentError(ReaderError.formatNotSupported, from: navigationController)
                return
            }

            do {
                let readerViewController = try await module.makeReaderViewController(
                    for: publication,
                    locator: book.locator,
                    bookId: bookId,
                    books: books,
                    bookmarks: bookmarks,
                    highlights: highlights,
                    readium: readium
                )
                await present(readerViewController)
            } catch {
                delegate.presentError(UserError(error), from: navigationController)
            }
        }
    }
}

extension ReaderModule: ReaderFormatModuleDelegate {
    func presentDRM(for publication: Publication, from viewController: UIViewController) {
        #if LCP
            guard let drmViewController: LCPManagementTableViewController = factory.make(publication: publication, delegate: delegate) else {
                return
            }
            let backItem = UIBarButtonItem()
            backItem.title = ""
            drmViewController.navigationItem.backBarButtonItem = backItem
            viewController.navigationController?.pushViewController(drmViewController, animated: true)
        #endif
    }

    func presentOutline(of publication: Publication, bookId: Book.Id, from viewController: UIViewController) -> AnyPublisher<Locator, Never> {
        let outlineAdapter = factory.make(publication: publication, bookId: bookId, bookmarks: bookmarks, highlights: highlights)
        let outlineLocatorPublisher = outlineAdapter.1

        viewController.present(UINavigationController(rootViewController: outlineAdapter.0), animated: true)

        return outlineLocatorPublisher
    }

    func presentAlert(_ title: String, message: String, from viewController: UIViewController) {
        delegate?.presentAlert(title, message: message, from: viewController)
    }

    func presentError<T: UserErrorConvertible>(_ error: T, from viewController: UIViewController) {
        delegate?.presentError(error, from: viewController)
    }
}
