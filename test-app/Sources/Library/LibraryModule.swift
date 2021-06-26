//
//  LibraryModule.swift
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
import R2Shared
import R2Streamer
import UIKit


/// The Library module handles the presentation of the bookshelf, and the publications' management.
protocol LibraryModuleAPI {
    
    var delegate: LibraryModuleDelegate? { get }
    
    /// Root navigation controller containing the Library.
    /// Can be used to present the library to the user.
    var rootViewController: UINavigationController { get }
    
    /// Loads the sample publications if needed.
    func preloadSamples() throws
    
    /// Imports a new publication to the library, either from:
    /// - a local file URL
    /// - a remote URL which will be downloaded
    ///
    /// - Parameters:
    ///   - url: Source URL to import.
    ///   - title: Title of the publication when known, to provide context.
    func importPublication(from url: URL, title: String?, sender: UIViewController, completion: @escaping (CancellableResult<Book, LibraryError>) -> Void)

}

extension LibraryModuleAPI {
    
    func importPublication(from url: URL, title: String? = nil, sender: UIViewController) {
        importPublication(from: url, title: title, sender: sender, completion: { _ in })
    }
    
}

protocol LibraryModuleDelegate: ModuleDelegate {
    
    /// Called when the user tap on a publication in the library.
    func libraryDidSelectPublication(_ publication: Publication, book: Book, completion: @escaping () -> Void)

}


final class LibraryModule: LibraryModuleAPI {

    weak var delegate: LibraryModuleDelegate?
    
    private let library: LibraryService
    private let factory: LibraryFactory

    init(delegate: LibraryModuleDelegate?, server: PublicationServer) {
        self.library = LibraryService(publicationServer: server)
        self.factory = LibraryFactory(libraryService: library)
        self.delegate = delegate
    }
    
    private(set) lazy var rootViewController: UINavigationController = {
        return UINavigationController(rootViewController: libraryViewController)
    }()

    private lazy var libraryViewController: LibraryViewController = {
        let library: LibraryViewController = factory.make()
        library.libraryDelegate = delegate
        return library
    }()
    
    func preloadSamples() throws {
        try library.preloadSamples()
    }
    
    func importPublication(from url: URL, title: String?, sender: UIViewController, completion: @escaping (CancellableResult<Book, LibraryError>) -> ()) {
        library.importPublication(from: url, title: title, sender: sender, completion: completion)
    }

}
