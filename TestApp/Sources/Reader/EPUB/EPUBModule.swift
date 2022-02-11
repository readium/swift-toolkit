//
//  EPUB.swift
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


final class EPUBModule: ReaderFormatModule {
    
    weak var delegate: ReaderFormatModuleDelegate?
    
    init(delegate: ReaderFormatModuleDelegate?) {
        self.delegate = delegate
    }

    func supports(_ publication: Publication) -> Bool {
        return publication.conforms(to: .epub)
            || publication.readingOrder.allAreHTML
    }
    
    func makeReaderViewController(for publication: Publication, locator: Locator?, bookId: Book.Id, books: BookRepository, bookmarks: BookmarkRepository, highlights: HighlightRepository, resourcesServer: ResourcesServer) throws -> UIViewController {
        guard publication.metadata.identifier != nil else {
            throw ReaderError.epubNotValid
        }
        
        let epubViewController = EPUBViewController(publication: publication, locator: locator, bookId: bookId, books: books, bookmarks: bookmarks, highlights: highlights, resourcesServer: resourcesServer)
        epubViewController.moduleDelegate = delegate
        return epubViewController
    }
    
}
