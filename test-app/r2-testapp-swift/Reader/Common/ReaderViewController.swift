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

import SafariServices
import UIKit
import R2Navigator
import R2Shared


/// This class is meant to be subclassed by each publication format view controller. It contains the shared behavior, eg. navigation bar toggling.
class ReaderViewController: UIViewController, Loggable {
    
    weak var moduleDelegate: ReaderFormatModuleDelegate?
    
    let navigator: UIViewController & Navigator
    let publication: Publication
    let drm: DRM?

    lazy var bookmarksDataSource: BookmarkDataSource? = BookmarkDataSource(publicationID: publication.metadata.identifier ?? "")
    
    // FIXME: Should be moved into Book.progression.
    static func initialLocation(for publication: Publication) -> Locator? {
        guard let publicationID = publication.metadata.identifier,
            let locatorJSON = UserDefaults.standard.string(forKey: "\(publicationID)-locator") else {
                return nil
        }
        return (try? Locator(jsonString: locatorJSON)) as? Locator
    }
    
    init(navigator: UIViewController & Navigator, publication: Publication, drm: DRM?) {
        self.navigator = navigator
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
      
        navigationItem.rightBarButtonItems = makeNavigationBarButtons()
        
        addChild(navigator)
        navigator.view.frame = view.bounds
        navigator.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigator.view)
        navigator.didMove(toParent: self)
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

    
    // MARK: - Locations
    /// FIXME: This should be implemented in a shared Navigator interface, using Locators.
    
    var currentBookmark: Bookmark? {
        fatalError("Not implemented")
    }
    
    var outline: [Link] {
        return publication.tableOfContents
    }

    func goTo(item: String) {
        navigator.go(to: Link(href: item))
    }
    
    func goTo(bookmark: Bookmark) {
        navigator.go(to: bookmark.locator)
    }
    
    
    // MARK: - Table of Contents

    @objc func presentOutline() {
        moduleDelegate?.presentOutline(of: publication, delegate: self, from: self)
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

extension ReaderViewController: NavigatorDelegate {

    func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
        guard let publicationID = publication.metadata.identifier else {
            return
        }
        UserDefaults.standard.set(locator.jsonString, forKey: "\(publicationID)-locator")
    }
    
    func navigator(_ navigator: Navigator, presentExternalURL url: URL) {
        present(SFSafariViewController(url: url), animated: true)
    }
    
    func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
        moduleDelegate?.presentError(error, from: self)
    }
    
}

extension ReaderViewController: VisualNavigatorDelegate {
    
    func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint) {
        let viewport = navigator.view.bounds
        // Skips to previous/next pages if the tap is on the content edges.
        let thresholdRange = 0...(0.2 * viewport.width)
        var moved = false
        if thresholdRange ~= point.x {
            moved = navigator.goLeft(animated: false)
        } else if thresholdRange ~= (viewport.maxX - point.x) {
            moved = navigator.goRight(animated: false)
        }
        
        if !moved {
            toggleNavigationBar()
        }
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
