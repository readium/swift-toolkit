//
//  ReaderModule.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 22.02.19.
//
//  Copyright 2019 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared
import Combine

/// The ReaderModule handles the presentation of publications to be read by the user.
/// It contains sub-modules implementing ReaderFormatModule to handle each format of publication (eg. CBZ, EPUB).
protocol ReaderModuleAPI {
    
    var delegate: ReaderModuleDelegate? { get }
    
    /// Presents the given publication to the user, inside the given navigation controller.
    /// - Parameter completion: Called once the publication is presented, or if an error occured.
    func presentPublication(publication: Publication, book: Book, in navigationController: UINavigationController, completion: @escaping () -> Void)
    
}

protocol ReaderModuleDelegate: ModuleDelegate {
}


final class ReaderModule: ReaderModuleAPI {
    
    weak var delegate: ReaderModuleDelegate?
    private let books: BookRepository
    private let bookmarks: BookmarkRepository
    private let highlights: HighlightRepository
    private let resourcesServer: ResourcesServer
    
    /// Sub-modules to handle different publication formats (eg. EPUB, CBZ)
    var formatModules: [ReaderFormatModule] = []
    
    private let factory = ReaderFactory()
    
    init(delegate: ReaderModuleDelegate?, books: BookRepository, bookmarks: BookmarkRepository, highlights: HighlightRepository, resourcesServer: ResourcesServer) {
        self.delegate = delegate
        self.books = books
        self.bookmarks = bookmarks
        self.highlights = highlights
        self.resourcesServer = resourcesServer
        
        formatModules = [
            CBZModule(delegate: self),
            EPUBModule(delegate: self),
        ]
        
        if #available(iOS 11.0, *) {
            formatModules.append(PDFModule(delegate: self))
        }
    }
    
    func presentPublication(publication: Publication, book: Book, in navigationController: UINavigationController, completion: @escaping () -> Void) {
        guard let delegate = delegate, let bookId = book.id else {
            fatalError("Reader delegate not set")
        }
        
        func present(_ viewController: UIViewController) {
            let backItem = UIBarButtonItem()
            backItem.title = ""
            viewController.navigationItem.backBarButtonItem = backItem
            viewController.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(viewController, animated: true)
        }
        
        guard let module = self.formatModules.first(where:{ $0.supports(publication) }) else {
            delegate.presentError(ReaderError.formatNotSupported, from: navigationController)
            completion()
            return
        }

        do {
            let readerViewController = try module.makeReaderViewController(for: publication, locator: book.locator, bookId: bookId, books: books, bookmarks: bookmarks, highlights: highlights, resourcesServer: resourcesServer)
            present(readerViewController)
        } catch {
            delegate.presentError(error, from: navigationController)
        }

        completion()
    }
    
}


extension ReaderModule: ReaderFormatModuleDelegate {

    func presentDRM(for publication: Publication, from viewController: UIViewController) {
        let drmViewController: DRMManagementTableViewController = factory.make(publication: publication, delegate: delegate)
        let backItem = UIBarButtonItem()
        backItem.title = ""
        drmViewController.navigationItem.backBarButtonItem = backItem
        viewController.navigationController?.pushViewController(drmViewController, animated: true)
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
    
    func presentError(_ error: Error?, from viewController: UIViewController) {
        delegate?.presentError(error, from: viewController)
    }

}
