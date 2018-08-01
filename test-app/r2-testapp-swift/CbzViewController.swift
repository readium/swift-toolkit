//
//  CbzViewController.swift
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
import R2Streamer
import R2Navigator

class CbzViewController: CbzNavigatorViewController {

    lazy var bookmarkDataSource = BookmarkDataSource(thePublicationID: self.publication.metadata.identifier ?? "")
    lazy var bookmarkVC: BookmarkViewController = {
        let result = BookmarkViewController(dataSource: self.bookmarkDataSource)
        result.didSelectBookmark = { (theBookmark:Bookmark) -> Void in
            self.load(at: theBookmark.spineIndex)
            self.navigationController?.popViewController(animated: true)
        }
        return result
    } ()
    lazy var spineListVC = SpineItemsTableViewController(for: publication.spine) { (spineIndex) in
        self.load(at: spineIndex)
        self.navigationController?.popViewController(animated: true)
    }
    
    lazy var locatorVC: LocatorViewController = {
        let result = LocatorViewController()
        result.setContent(tocVC: self.spineListVC, bookmarkVC: self.bookmarkVC)
        return result
    } ()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.navigationBar.tintColor = UIColor.black
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        /// Gesture recognisers.
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(loadNext))
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(loadPrevious))

        swipeLeft.direction = UISwipeGestureRecognizerDirection.left
        swipeRight.direction = UISwipeGestureRecognizerDirection.right
        view.addGestureRecognizer(swipeRight)
        view.addGestureRecognizer(swipeLeft)
        // SpineItemView button.
        let spineItemButton = UIBarButtonItem(image: #imageLiteral(resourceName: "menuIcon"), style: .plain, target: self,
                                              action: #selector(presentSpineItemsTVC))
        
        let bookmarkButton = UIBarButtonItem(image: #imageLiteral(resourceName: "bookmark"), style: .plain, target: self, action: #selector(addBookmarkForCurrentPosition))
        /// Add spineItemViewController button to navBar.
        navigationItem.setRightBarButtonItems([spineItemButton, bookmarkButton], animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.hidesBarsOnTap = true
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.hidesBarsOnTap = false
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return UIStatusBarAnimation.slide
    }

    open override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @objc func addBookmarkForCurrentPosition() {
        
        let spineIndex = pageNumber
        let progression = 0.0
        if spineIndex == 0 {return}
        
        guard let publicationID = publication.metadata.identifier else {return}
        let spineDescription = publication.spine[spineIndex].href ?? "Unknow"
        
        let newBookmark = Bookmark(spineIndex: spineIndex, progression: progression, description: spineDescription, publicationID: publicationID)
        _ = self.bookmarkVC.dataSource.addBookmark(newBookmark: newBookmark)
        self.bookmarkVC.tableView.reloadData()
    }
}

extension CbzViewController {
    @objc func presentSpineItemsTVC() {
        let backItem = UIBarButtonItem()
        
        backItem.title = "Back"
        navigationItem.backBarButtonItem = backItem
        navigationController?.pushViewController(self.locatorVC, animated: true)
    }
}
