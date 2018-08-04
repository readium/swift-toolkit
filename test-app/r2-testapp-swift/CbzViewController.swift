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

    lazy var bookmarkDataSource = BookmarkDataSource(publicationID: self.publication.metadata.identifier ?? "")
  
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
      if (self.bookmarkDataSource.addBookmark(bookmark: bookmark)) {
        toast(self.view, "Bookmark Added", 1)
      } else {
        toast(self.view, "Could not add Bookmark", 2)
      }
    }
}

extension CbzViewController {
    @objc func presentSpineItemsTVC() {
            
      let storyboard = UIStoryboard(name: "AppMain", bundle: nil)
      let outlineTableVC =
        storyboard.instantiateViewController(withIdentifier: "OutlineTableViewController") as! OutlineTableViewController
      
      outlineTableVC.publicationType = .CBZ
      outlineTableVC.tableOfContents = publication.spine
      outlineTableVC.bookmarksDatasource = self.bookmarkDataSource
      outlineTableVC.callBack = { (spineIndex) in
        self.load(at: Int(spineIndex)!)
      }
      outlineTableVC.didSelectBookmark = { (bookmark:Bookmark) -> Void in
        self.load(at: bookmark.resourceIndex)
      }
      
      let outlineNavVC = UINavigationController.init(rootViewController: outlineTableVC)
      present(outlineNavVC, animated: true, completion: nil)
    }
}
