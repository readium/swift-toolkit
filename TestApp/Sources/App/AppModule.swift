//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import R2Shared
import R2Streamer
import UIKit

/// Base module delegate, that sub-modules' delegate can extend.
/// Provides basic shared functionalities.
protocol ModuleDelegate: AnyObject {
    func presentAlert(_ title: String, message: String, from viewController: UIViewController)
    func presentError(_ error: Error?, from viewController: UIViewController)
}

/// Main application module, it:
/// - owns the sub-modules (library, reader, etc.)
/// - orchestrates the communication between its sub-modules, through the modules' delegates.
final class AppModule {
    // App modules
    var library: LibraryModuleAPI!
    var reader: ReaderModuleAPI!
    var opds: OPDSModuleAPI!

    init() throws {
        let httpClient = DefaultHTTPClient()
        let db = try Database(file: Paths.library.appendingPathComponent("database.db"))
        let books = BookRepository(db: db)
        let bookmarks = BookmarkRepository(db: db)
        let highlights = HighlightRepository(db: db)

        library = LibraryModule(delegate: self, books: books, httpClient: httpClient)
        reader = ReaderModule(delegate: self, books: books, bookmarks: bookmarks, highlights: highlights)
        opds = OPDSModule(delegate: self)

        // Set Readium 2's logging minimum level.
        R2EnableLog(withMinimumSeverityLevel: .debug)
    }

    private(set) lazy var aboutViewController: UIViewController = {
        let storyboard = UIStoryboard(name: "App", bundle: nil)
        let aboutViewController = storyboard.instantiateViewController(withIdentifier: "AboutTableViewController") as! AboutTableViewController
        return UINavigationController(rootViewController: aboutViewController)
    }()
}

extension AppModule: ModuleDelegate {
    func presentAlert(_ title: String, message: String, from viewController: UIViewController) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let dismissButton = UIAlertAction(title: NSLocalizedString("ok_button", comment: "Alert button"), style: .cancel)
            alert.addAction(dismissButton)
            viewController.present(alert, animated: true)
        }
    }

    func presentError(_ error: Error?, from viewController: UIViewController) {
        guard let error = error else { return }
        if case LibraryError.cancelled = error { return }
        presentAlert(
            NSLocalizedString("error_title", comment: "Alert title for errors"),
            message: error.localizedDescription,
            from: viewController
        )
    }
}

extension AppModule: LibraryModuleDelegate {
    func libraryDidSelectPublication(_ publication: Publication, book: Book) {
        reader.presentPublication(publication: publication, book: book, in: library.rootViewController)
    }
}

extension AppModule: ReaderModuleDelegate {}

extension AppModule: OPDSModuleDelegate {
    func opdsDownloadPublication(_ publication: Publication?, at link: Link, sender: UIViewController) async throws -> Book {
        guard let url = link.url(relativeTo: publication?.baseURL) else {
            throw LibraryError.cancelled
        }

        return try await library.importPublication(from: url, sender: sender)
    }
}
