//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import ReadiumShared
import ReadiumStreamer
import SwiftUI
import UIKit

/// Base module delegate, that sub-modules' delegate can extend.
/// Provides basic shared functionalities.
protocol ModuleDelegate: AnyObject {
    func presentAlert(_ title: String, message: String, from viewController: UIViewController)
    func presentError<T: UserErrorConvertible>(_ error: T, from viewController: UIViewController)
}

/// Main application module, it:
/// - owns the sub-modules (library, reader, etc.)
/// - orchestrates the communication between its sub-modules, through the modules' delegates.
final class AppModule {
    // App modules
    var library: LibraryModuleAPI!
    var reader: ReaderModuleAPI!
    var opds: OPDSModuleAPI!

    let readium: Readium

    init() throws {
        let file = Paths.library.appendingPath("database.db", isDirectory: false)
        let db = try Database(file: file.url)
        print("Created database at \(file.path)")

        let books = BookRepository(db: db)
        let bookmarks = BookmarkRepository(db: db)
        let highlights = HighlightRepository(db: db)

        readium = Readium()

        library = LibraryModule(
            delegate: self,
            books: books,
            readium: readium
        )

        reader = ReaderModule(
            delegate: self,
            books: books,
            bookmarks: bookmarks,
            highlights: highlights,
            readium: readium
        )

        opds = OPDSModule(delegate: self)

        // Set Readium 2's logging minimum level.
        ReadiumEnableLog(withMinimumSeverityLevel: .info)
    }

    private(set) lazy var aboutViewController: UIViewController = {
        let hostingController = UIHostingController(rootView: AboutView())
        hostingController.navigationItem.title = "About the Readium Swift Toolkit"
        hostingController.navigationItem.largeTitleDisplayMode = .never
        return UINavigationController(rootViewController: hostingController)
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

    func presentError<T: UserErrorConvertible>(_ error: T, from viewController: UIViewController) {
        viewController.alert(error)
    }
}

extension AppModule: LibraryModuleDelegate {
    func libraryDidSelectPublication(_ publication: Publication, book: Book) {
        reader.presentPublication(publication: publication, book: book, in: library.rootViewController)
    }
}

extension AppModule: ReaderModuleDelegate {}

extension AppModule: OPDSModuleDelegate {
    func opdsDownloadPublication(
        _ publication: Publication?,
        at link: ReadiumShared.Link,
        sender: UIViewController,
        progress: @escaping (Double) -> Void
    ) async throws -> Book {
        guard let url = link.url(relativeTo: publication?.baseURL).httpURL else {
            throw OPDSError.invalidURL(link.href)
        }

        let fileURL = try await readium.httpClient.download(url, onProgress: progress).get().location
        return try await library.importPublication(from: fileURL, sender: sender, progress: progress)
    }
}
