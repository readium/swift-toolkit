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
import R2Navigator
import R2Shared
import R2Streamer


class CbzViewController: CbzNavigatorViewController {
    
    weak var moduleDelegate: ReaderFormatModuleDelegate?
    
    lazy var bookmarksDataSource: BookmarkDataSource? = BookmarkDataSource(publicationID: self.publication.metadata.identifier ?? "")
    
    public init(publication: Publication) {
        super.init(for: publication, initialIndex: 0)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
  
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
      let resourceIndex = pageNumber
      let progression = 0.0
    
      guard let publicationID = publication.metadata.identifier else {return}
      let spineDescription = publication.spine[resourceIndex].href ?? "Unknow"
        
      let bookmark = Bookmark(resourceHref:spineDescription, resourceIndex: resourceIndex, progression: progression, resourceTitle: spineDescription, publicationID: publicationID)
      if (bookmarksDataSource?.addBookmark(bookmark: bookmark) ?? false) {
        toast(self.view, "Bookmark Added", 1)
      } else {
        toast(self.view, "Could not add Bookmark", 2)
      }
    }
}

extension CbzViewController {
    @objc func presentSpineItemsTVC() {
        moduleDelegate?.presentOutline(publication.spine, type: .cbz, delegate: self, from: self)
    }
}

extension CbzViewController: OutlineTableViewControllerDelegate {
    
    func outline(_ outlineTableViewController: OutlineTableViewController, didSelectItem item: String) {
        load(at: Int(item)!)
    }
    
    func outline(_ outlineTableViewController: OutlineTableViewController, didSelectBookmark bookmark: Bookmark) {
        load(at: bookmark.resourceIndex)
    }
    
}
