//
//  AppModule.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 20.02.19.
//
//  Copyright 2019 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Combine
import Foundation
import UIKit
import R2Shared
import R2Streamer


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
    var library: LibraryModuleAPI! = nil
    var reader: ReaderModuleAPI! = nil
    var opds: OPDSModuleAPI! = nil

    init() throws {
        guard let server = PublicationServer() else {
            /// FIXME: we should recover properly if the publication server can't start, maybe this should only forbid opening a publication?
            fatalError("Can't start publication server")
        }
        
        let httpClient = DefaultHTTPClient()
        let db = try Database(file: Paths.library.appendingPathComponent("database.db"))
        let books = BookRepository(db: db)
        let bookmarks = BookmarkRepository(db: db)
        let highlights = HighlightRepository(db: db)
        
        library = LibraryModule(delegate: self, books: books, server: server, httpClient: httpClient)
        reader = ReaderModule(delegate: self, books: books, bookmarks: bookmarks, highlights: highlights, resourcesServer: server)
        opds = OPDSModule(delegate: self)
        
        // Set Readium 2's logging minimum level.
        R2EnableLog(withMinimumSeverityLevel: .warning)
    }
    
    private(set) lazy var aboutViewController: UIViewController = {
        let storyboard = UIStoryboard(name: "App", bundle: nil)
        let aboutViewController = storyboard.instantiateViewController(withIdentifier: "AboutTableViewController") as! AboutTableViewController
        return UINavigationController(rootViewController: aboutViewController)
    }()

}


extension AppModule: ModuleDelegate {

    func presentAlert(_ title: String, message: String, from viewController: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let dismissButton = UIAlertAction(title: NSLocalizedString("ok_button", comment: "Alert button"), style: .cancel)
        alert.addAction(dismissButton)
        viewController.present(alert, animated: true)
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
    
    func libraryDidSelectPublication(_ publication: Publication, book: Book, completion: @escaping () -> Void) {
        reader.presentPublication(publication: publication, book: book, in: library.rootViewController, completion: completion)
    }

}


extension AppModule: ReaderModuleDelegate {
}


extension AppModule: OPDSModuleDelegate {
    
    func opdsDownloadPublication(_ publication: Publication?, at link: Link, sender: UIViewController) -> AnyPublisher<Book, LibraryError> {
        guard let url = link.url(relativeTo: publication?.baseURL) else {
            return .fail(.cancelled)
        }
        
        return library.importPublication(from: url, sender: sender)
    }

}
