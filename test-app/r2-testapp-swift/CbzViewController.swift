//
//  CbzViewController.swift
//  r2-navigator
//
//  Created by Alexandre Camilleri on 6/28/17.
//  Copyright © 2017 European Digital Reading Lab. All rights reserved.
//

import UIKit
import R2Streamer
import R2Navigator

class CbzViewController: CbzNavigatorViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
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
        let spineItemButton = UIBarButtonItem(title: "📖", style: .plain, target: self,
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
    func presentSpineItemsTVC() {
        let backItem = UIBarButtonItem()
        let spineItemsTVC = SpineItemsTableViewController(for: publication.spine, callWhenDismissed: load(at:))
    
        backItem.title = "Back"
        navigationItem.backBarButtonItem = backItem
        navigationController?.pushViewController(spineItemsTVC, animated: true)
    }
}
