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
        /// Add spineItemViewController button to navBar.
        navigationItem.setRightBarButtonItems([spineItemButton], animated: true)
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
}

extension CbzViewController {
    @objc func presentSpineItemsTVC() {
        let backItem = UIBarButtonItem()
        let spineItemsTVC = SpineItemsTableViewController(for: publication.spine, callWhenDismissed: load(at:))
    
        backItem.title = "Back"
        navigationItem.backBarButtonItem = backItem
        navigationController?.pushViewController(spineItemsTVC, animated: true)
    }
}
