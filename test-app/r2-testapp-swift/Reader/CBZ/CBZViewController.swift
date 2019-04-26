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

    let navigator: CBZNavigatorViewController

    override init(publication: Publication, drm: DRM?, initialLocation: Locator?) {
        navigator = CBZNavigatorViewController(publication: publication, initialLocation: initialLocation)

        super.init(publication: publication, drm: nil, initialLocation: initialLocation)
        
        navigator.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        addChild(navigator)
        navigator.view.frame = view.bounds
        navigator.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigator.view)
        navigator.didMove(toParent: self)
    }
    
    override var outline: [Link] {
        return publication.readingOrder
    }

    override var currentBookmark: Bookmark? {
        guard let publicationID = publication.metadata.identifier,
            let locator = navigator.currentLocation,
            let resourceIndex = publication.readingOrder.firstIndex(withHref: locator.href) else
        {
            return nil
        }
        
        return Bookmark(
            publicationID: publicationID,
            resourceIndex: resourceIndex,
            locator: locator
        )
    }
    
    override func goTo(item: String) {
        guard let index = Int(item),
            publication.readingOrder.indices.contains(index) else
        {
            return
        }
        
        navigator.go(to: publication.readingOrder[index])
    }
    
    override func goTo(bookmark: Bookmark) {
        navigator.go(to: bookmark.locator)
    }
    
}

extension CBZViewController: CBZNavigatorDelegate {
}
