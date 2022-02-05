//
//  CBZModule.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 22.02.19.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared


final class CBZModule: ReaderFormatModule {
    
    weak var delegate: ReaderFormatModuleDelegate?
    
    init(delegate: ReaderFormatModuleDelegate?) {
        self.delegate = delegate
    }
    
    func supports(_ publication: Publication) -> Bool {
        return publication.conforms(to: .divina)
    }
    
    func makeReaderViewController(for publication: Publication, locator: Locator?, bookId: Book.Id, books: BookRepository, bookmarks: BookmarkRepository, highlights: HighlightRepository, resourcesServer: ResourcesServer) throws -> UIViewController {
        let cbzVC = CBZViewController(publication: publication, locator: locator, bookId: bookId, books: books, bookmarks: bookmarks)
        cbzVC.moduleDelegate = self.delegate
        return cbzVC
    }

}
