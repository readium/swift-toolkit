//
//  ReaderViewController.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 07.03.19.
//
//  Copyright 2019 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Shared


/// This class is meant to be subclassed by each publication format view controller. It contains the shared behavior, eg. navigation bar toggling.
class ReaderViewController: UIViewController, Loggable {
    
    weak var moduleDelegate: ReaderFormatModuleDelegate?
    
    let publication: Publication
    let drm: DRM?
    
    lazy var bookmarksDataSource: BookmarkDataSource? = BookmarkDataSource(publicationID: publication.metadata.identifier ?? "")
    
    init(publication: Publication, drm: DRM?) {
        self.publication = publication
        self.drm = drm
        
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        navigationItem.rightBarButtonItems = makeNavigationBarButtons()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.hidesBarsOnTap = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        navigationController?.hidesBarsOnTap = false
    }
    
    override func willMove(toParent parent: UIViewController?) {
        // Restore library's default UI colors
        navigationController?.navigationBar.tintColor = .black
        navigationController?.navigationBar.barTintColor = .white
    }
    
    
    // MARK: - Navigation bar
    
    func makeNavigationBarButtons() -> [UIBarButtonItem] {
        let tocButton = UIBarButtonItem(image: #imageLiteral(resourceName: "menuIcon"), style: .plain, target: self, action: #selector(presentOutline))
        let bookmarkButton = UIBarButtonItem(image: #imageLiteral(resourceName: "bookmark"), style: .plain, target: self, action: #selector(bookmarkCurrentPosition))
        return [tocButton, bookmarkButton]
    }
    
    func toggleNavigationBar() {
        guard let state = navigationController?.isNavigationBarHidden else {
            return
        }
        navigationController?.setNavigationBarHidden(!state, animated: true)
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? true
    }
    
    /// Called when the reader view controller will present any view controller. You can override this function to update the UX accordingly.
    func willPresentViewController() {
        // Default does nothing.
    }
    
    
    // MARK: - Locations
    /// FIXME: This should be implemented in a shared Navigator interface, using Locators.
    
    var currentBookmark: Bookmark? {
        fatalError("Not implemented")
    }
    
    var outline: [Link] {
        return publication.tableOfContents
    }
    
    func goTo(item: String) {
        fatalError("Not implemented")
    }
    
    func goTo(bookmark: Bookmark) {
        fatalError("Not implemented")
    }
    
    
    // MARK: - Table of Contents

    @objc func presentOutline() {
        moduleDelegate?.presentOutline(publication, format: publication.format, delegate: self, from: self)
    }
    
    
    // MARK: - Bookmarks
    
    @objc func bookmarkCurrentPosition() {
        guard let dataSource = bookmarksDataSource,
            let bookmark = currentBookmark,
            dataSource.addBookmark(bookmark: bookmark) else
        {
            toast(self.view, "Could not add Bookmark", 2)
            return
        }
        toast(self.view, "Bookmark Added", 1)
    }

}


extension ReaderViewController: OutlineTableViewControllerDelegate {
    
    func outline(_ outlineTableViewController: OutlineTableViewController, didSelectItem item: String) {
        goTo(item: item)
    }
    
    func outline(_ outlineTableViewController: OutlineTableViewController, didSelectBookmark bookmark: Bookmark) {
        goTo(bookmark: bookmark)
    }
    
}
