//
//  LibraryFactory.swift
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


final class LibraryFactory {
    
    fileprivate let storyboard = UIStoryboard(name: "Library", bundle: nil)
    fileprivate let libraryService: LibraryService

    init(libraryService: LibraryService) {
        self.libraryService = libraryService
    }
    
}

extension LibraryFactory: LibraryViewControllerFactory {
    func make() -> LibraryViewController {
        let library = storyboard.instantiateViewController(withIdentifier: "LibraryViewController") as! LibraryViewController
        library.factory = self
        library.library = libraryService
        return library
    }
}

extension LibraryFactory: DetailsTableViewControllerFactory {
    func make(publication: Publication) -> DetailsTableViewController {
        let controller = storyboard.instantiateViewController(withIdentifier: "DetailsTableViewController") as! DetailsTableViewController
        controller.publication = publication
        return controller
    }
}

