//
//  CBZViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 6/28/17.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Navigator
import R2Shared
import R2Streamer


class CBZViewController: ReaderViewController {

    init(publication: Publication, book: Book) {
        let navigator = CBZNavigatorViewController(publication: publication, initialLocation: book.progressionLocator)
        
        super.init(navigator: navigator, publication: publication, book: book)
        
        navigator.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
    }
    
    override var currentBookmark: Bookmark? {
        guard
            let locator = navigator.currentLocation,
            let resourceIndex = publication.readingOrder.firstIndex(withHREF: locator.href) else
        {
            return nil
        }
        
        return Bookmark(
            bookID: book.id,
            resourceIndex: resourceIndex,
            locator: locator
        )
    }

}

extension CBZViewController: CBZNavigatorDelegate {
}
