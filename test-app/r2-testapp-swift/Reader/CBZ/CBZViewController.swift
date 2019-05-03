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

    public init(publication: Publication) {
        navigator = CBZNavigatorViewController(for: publication, initialIndex: 0)
        
        super.init(publication: publication, drm: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        addChild(navigator)
        navigator.view.frame = view.bounds
        navigator.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigator.view)
        navigator.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        /// Gesture recognisers.
        let swipeLeft = UISwipeGestureRecognizer(target: navigator, action: #selector(CBZNavigatorViewController.loadNext))
        let swipeRight = UISwipeGestureRecognizer(target: navigator, action: #selector(CBZNavigatorViewController.loadPrevious))

        swipeLeft.direction = UISwipeGestureRecognizer.Direction.left
        swipeRight.direction = UISwipeGestureRecognizer.Direction.right
        view.addGestureRecognizer(swipeRight)
        view.addGestureRecognizer(swipeLeft)
    }
    
    override var outline: [Link] {
        return publication.readingOrder
    }

    override var currentBookmark: Bookmark? {
        let resourceIndex = navigator.pageNumber
        let progression = 0.0
        
        guard let publicationID = publication.metadata.identifier else {
            return nil
        }
        
        let resourceTitle = publication.readingOrder[resourceIndex].title
        let resourceHref = publication.readingOrder[resourceIndex].href
        let resourceType = publication.readingOrder[resourceIndex].type ?? ""
        
        return Bookmark(
            publicationID: publicationID,
            resourceIndex: resourceIndex,
            locator: Locator(
                href: resourceHref,
                type: resourceType,
                title: resourceTitle,
                locations: Locations(
                    progression: progression
                )
            )
        )
    }
    
    override func goTo(item: String) {
        navigator.load(at: Int(item)!)
    }
    
    override func goTo(bookmark: Bookmark) {
        navigator.load(at: bookmark.resourceIndex)
    }
    
}
