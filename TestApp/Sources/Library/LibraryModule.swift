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

import Combine
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

}

protocol LibraryModuleDelegate: ModuleDelegate {
    
    /// Called when the user tap on a publication in the library.
    func libraryDidSelectPublication(_ publication: Publication, book: Book, completion: @escaping () -> Void)

}


final class LibraryModule: LibraryModuleAPI {

    weak var delegate: LibraryModuleDelegate?
    
    private var factory: LibraryFactory!
    private var subscriptions = Set<AnyCancellable>()

    init(delegate: LibraryModuleDelegate?, books: BookRepository, server: PublicationServer, httpClient: HTTPClient) {
        
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
}
