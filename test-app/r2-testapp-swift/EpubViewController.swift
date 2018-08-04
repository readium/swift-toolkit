//
//  EpubViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 7/3/17.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Shared
import R2Navigator

class EpubViewController: UIViewController {
    let stackView: UIStackView!
    let navigator: NavigatorViewController!
    let fixedTopBar: BarView!
    let fixedBottomBar: BarView!
    var tableOfContentsTVC: TableOfContentsTableViewController!
    var popoverUserconfigurationAnchor: UIBarButtonItem?
    var userSettingNavigationController: UserSettingsNavigationController!
    var drmManagementTVC: DrmManagementTableViewController!
    var haveDrm = false
    
    lazy var locatorViewController:LocatorViewController = {
        let result = LocatorViewController()
        result.setContent(tocVC: self.tableOfContentsTVC, bookmarkVC: self.bookmarkViewController)
        return result
    } ()
    
    lazy var bookmarkDataSource: BookmarkDataSource = {
        let publicationID = navigator.publication.metadata.identifier ?? ""
        return BookmarkDataSource(thePublicationID:publicationID)
    } ()
    
    lazy var bookmarkViewController: BookmarkViewController = {
        let theVC = BookmarkViewController(dataSource: self.bookmarkDataSource)
        
        theVC.didSelectBookmark = { (theBookmark:Bookmark) -> Void in
            self.navigator.displaySpineItem(at: theBookmark.spineIndex, progression: theBookmark.progression)
            self.navigationController?.popViewController(animated: true)
        }
        return theVC
    } ()
    
    lazy var markButton: UIBarButtonItem = {
        let theButton = UIBarButtonItem(image: #imageLiteral(resourceName: "bookmark"), style: .plain, target: self, action: #selector(addBookmarkForCurrentPosition))
        return theButton
    } ()
    
    lazy var hrefToTitle: [String: String] = {
        
        let linkList = self.navigator.getTableOfContents()
        return self.fulfill(linkList: linkList)
    } ()
    
    func fulfill(linkList: [Link]) -> [String: String] {
        var result = [String: String]()
        
        for linkItem in linkList {
            if let href = linkItem.href, let title = linkItem.title {
                result[href] = title
            }
            let subResult = fulfill(linkList: linkItem.children)
            result.merge(subResult) { (current, another) -> String in
                return current
            }
        }
        return result
    }
    
    @objc func addBookmarkForCurrentPosition() {
        
        let position = navigator.currentPosition
        
        let spineIndex = position.0
        let progression = position.1
        
        if spineIndex == 0 {return}
        
        let spine = self.navigator.getSpine()[spineIndex]
        let spineTitle: String = {
            if let spineHref = spine.href {
                return hrefToTitle[spineHref]
            }
            return nil
        } () ?? "Unknow"
        
        guard let publicationID = navigator.publication.metadata.identifier else {return}
        
        let newBookmark = Bookmark(spineIndex: spineIndex, progression: progression, description: spineTitle, publicationID: publicationID)
        _ = self.bookmarkViewController.dataSource.addBookmark(newBookmark: newBookmark)
        self.bookmarkViewController.tableView.reloadData()
    }
    
    init(with publication: Publication, atIndex index: Int, progression: Double?, _ drm: Drm?) {
        stackView = UIStackView(frame: UIScreen.main.bounds)
        navigator = NavigatorViewController(for: publication,
                                            initialIndex: index,
                                            initialProgression: progression)
        
        fixedTopBar = BarView()
        fixedBottomBar = BarView()
        tableOfContentsTVC = TableOfContentsTableViewController(for: navigator.getTableOfContents(),
                                                                callWhenDismissed: navigator.displaySpineItem(with:))
        // UserSettingsViewController.
        var storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        
        userSettingNavigationController =
            storyboard.instantiateViewController(withIdentifier: "UserSettingsNavigationController") as! UserSettingsNavigationController
        
        if drm != nil {
            haveDrm = true
            // DrmManagementViewController?
            storyboard = UIStoryboard(name: "DrmManagement", bundle: nil)
            drmManagementTVC =
                storyboard.instantiateViewController(withIdentifier: "DrmManagementTableViewController") as! DrmManagementTableViewController
            drmManagementTVC.drm = drm
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    deinit {
        navigator.userSettings.save()
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        view.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        stackView.addArrangedSubview(fixedTopBar)
        stackView.addArrangedSubview(navigator.view)
        stackView.addArrangedSubview(fixedBottomBar)
        
        view.addSubview(stackView)
        
        if #available(iOS 11, *) {
            let safeArea = view.safeAreaLayoutGuide
            stackView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: safeArea.topAnchor),
                self.stackView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
                self.stackView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
                self.stackView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            ])
        }
        
        /// Set initial UI appearance.
        if let appearance = navigator.publication.userProperties.getProperty(reference: ReadiumCSSReference.appearance.rawValue) {
            setUIColor(for: appearance)
        }
        
        userSettingNavigationController.modalPresentationStyle = .popover
        userSettingNavigationController.usdelegate = self
        
        fixedTopBar.delegate = self
        fixedBottomBar.delegate = self
        navigator.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fixedTopBar.setLabel(title: navigator.publication.metadata.title)
        fixedBottomBar.setLabel(title: "")
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        var barButtons = [UIBarButtonItem]()
        
        if navigator.getTableOfContents().count > 0 {
            // SpineItemView button.
            let spineItemButton = UIBarButtonItem(image: #imageLiteral(resourceName: "menuIcon"), style: .plain, target: self,
                                                  action: #selector(presentTableOfContents))
            barButtons.append(spineItemButton)
        }
        
        // User configuration button
        let userSettingsButton = UIBarButtonItem(image: #imageLiteral(resourceName: "settingsIcon"), style: .plain, target: self,
                                                 action: #selector(presentUserSettings))
        barButtons.append(userSettingsButton)
        
        if haveDrm {
            let drmManagementButton = UIBarButtonItem(image: #imageLiteral(resourceName: "drm"), style: .plain, target: self,
                                                      action: #selector(presentDrmManagement))
            barButtons.append(drmManagementButton)
        }
        
        barButtons.append(self.markButton)
        
        popoverUserconfigurationAnchor = userSettingsButton
        /// Add spineItemViewController button to navBar.
        navigationItem.setRightBarButtonItems(barButtons,
                                              animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.hidesBarsOnTap = true
        toggleFixedBars()
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        navigationController?.hidesBarsOnTap = false
    }
    
    override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        fixedTopBar.setNeedsUpdateConstraints()
        fixedBottomBar.setNeedsUpdateConstraints()
    }
    
    override open var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return UIStatusBarAnimation.slide
    }
    
    open override var prefersStatusBarHidden: Bool {
        // Prevent animation blinking when navigating back to the library
        // by always showing status bar when navigation bar is visible
        return navigationController?.isNavigationBarHidden == true
    }
    
    override func willMove(toParentViewController parent: UIViewController?) {
        // Restore library's default UI colors
        navigationController?.navigationBar.tintColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        navigationController?.navigationBar.barTintColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    }
}

extension EpubViewController {
    
    @objc func presentUserSettings() {
        let popoverPresentationController = userSettingNavigationController.popoverPresentationController!
        
        popoverPresentationController.delegate = self
        popoverPresentationController.barButtonItem = popoverUserconfigurationAnchor
        
        present(userSettingNavigationController, animated: true, completion: nil)
    }
    
    @objc func presentTableOfContents() {
        let backItem = UIBarButtonItem()
        
        backItem.title = ""
        navigationItem.backBarButtonItem = backItem
        // Dismiss userSettings if opened.
        if let userSettingsTVC = userSettingNavigationController.userSettingsTableViewController {
            userSettingsTVC.dismiss(animated: true, completion: nil)
        }
        navigationController?.pushViewController(locatorViewController, animated: true)
    }
    
    @objc func presentDrmManagement() {
        let backItem = UIBarButtonItem()
        
        backItem.title = ""
        navigationItem.backBarButtonItem = backItem
        // Dismiss userSettings if opened.
        if let userSettingsTVC = userSettingNavigationController.userSettingsTableViewController {
            userSettingsTVC.dismiss(animated: true, completion: nil)
        }
        self.navigationController?.pushViewController(drmManagementTVC, animated: true)
    }
}

extension EpubViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - Delegate of the NavigatorViewController (R2Navigator).
extension EpubViewController: NavigatorDelegate {
    
    func middleTapHandler() {
        guard let state = navigationController?.navigationBar.isHidden else {
            return
        }
        navigationController?.setNavigationBarHidden(!state, animated: true)
    }
    
    // The publication is being closed, provide info for saving progress.
    func willExitPublication(documentIndex: Int, progression: Double?) {
        guard let publicationIdentifier = navigator.publication.metadata.identifier else {
            return
        }
        let userDefaults = UserDefaults.standard
        // Save current publication's document's. 
        // (<=> the spine item)
        userDefaults.set(documentIndex, forKey: "\(publicationIdentifier)-document")
        // Save current publication's document's progression. 
        // (<=> the position in the spine item)
        userDefaults.set(progression, forKey: "\(publicationIdentifier)-documentProgression")
    }
}

extension EpubViewController: UserSettingsNavigationControllerDelegate {
    internal func getUserSettings() -> UserSettings {
        return navigator.userSettings
    }
    
    internal func updateUserSettingsStyle() {
        navigator.updateUserSettingStyle()
    }
    
    /// Synchronyze the UI appearance to the UserSettings.Appearance.
    ///
    /// - Parameter appearance: The appearance.
    internal func setUIColor(for appearance: UserProperty) {
        let colors = AssociatedColors.getColors(for: appearance)
        
        navigator.view.backgroundColor = colors.mainColor
        view.backgroundColor = colors.mainColor
        //
        navigationController?.navigationBar.barTintColor = colors.mainColor
        navigationController?.navigationBar.tintColor = colors.textColor
        
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: colors.textColor]
        
        //
        tableOfContentsTVC.setUIColor(for: appearance)
        if haveDrm {
            drmManagementTVC.appearance = appearance
        }
    }
    
    // Toggle hide/show fixed bot and top bars.
    internal func toggleFixedBars() {
        guard let scroll = navigator.userSettings.userProperties.getProperty(reference: ReadiumCSSReference.scroll.rawValue) as? Switchable else {
            return
        }
        
        let currentValue = scroll.on
        
        UIView.transition(with: fixedTopBar, duration: 0.318, options: .curveEaseOut, animations: {() -> Void in
            self.fixedTopBar.isHidden = currentValue
        }, completion: nil)
        UIView.transition(with: fixedBottomBar, duration: 0.318, options: .curveEaseOut, animations: {() -> Void in
            self.fixedBottomBar.isHidden = currentValue
        }, completion: nil)
    }
}

extension EpubViewController: UIPopoverPresentationControllerDelegate {
    // Prevent the popOver to be presented fullscreen on iPhones.
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle
    {
        return .none
    }
}
