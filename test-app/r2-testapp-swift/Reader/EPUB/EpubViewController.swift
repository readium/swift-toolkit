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

protocol EpubViewControllerFactory {
    func make(publication: Publication, at index: Int, progression: Double?, drm: DRM?) -> EpubViewController
}

class EpubViewController: UIViewController {
    
    weak var moduleDelegate: ReaderFormatModuleDelegate?
    
    let drm: DRM?
    let stackView: UIStackView!
    let navigator: NavigatorViewController!
    let fixedTopBar: BarView!
    let fixedBottomBar: BarView!
    var popoverUserconfigurationAnchor: UIBarButtonItem?
    var userSettingNavigationController: UserSettingsNavigationController

    init(publication: Publication, atIndex index: Int, progression: Double?, _ drm: DRM?) {
        self.drm = drm
        stackView = UIStackView(frame: UIScreen.main.bounds)
        navigator = NavigatorViewController(for: publication, initialIndex: index, initialProgression: progression, editingActions: [.lookup])
        
        fixedTopBar = BarView()
        fixedBottomBar = BarView()
        
        let settingsStoryboard = UIStoryboard(name: "UserSettings", bundle: nil)
        userSettingNavigationController = settingsStoryboard.instantiateViewController(withIdentifier: "UserSettingsNavigationController") as! UserSettingsNavigationController
        userSettingNavigationController.fontSelectionViewController =
            (settingsStoryboard.instantiateViewController(withIdentifier: "FontSelectionViewController") as! FontSelectionViewController)
        userSettingNavigationController.advancedSettingsViewController =
            (settingsStoryboard.instantiateViewController(withIdentifier: "AdvancedSettingsViewController") as! AdvancedSettingsViewController)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    deinit {
        navigator.userSettings.save()
    }
  
    lazy var bookmarksDataSource: BookmarkDataSource? = {
        let publicationID = navigator.publication.metadata.identifier ?? ""
        return BookmarkDataSource(publicationID:publicationID)
    } ()
  
    lazy var bookmarkButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: #imageLiteral(resourceName: "bookmark"), style: .plain, target: self, action: #selector(addBookmarkForCurrentPosition))
        return button
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
        
        let resourceIndex = position.0
        let progression = position.1
    
        let spine = self.navigator.getSpine()[resourceIndex]
        let spineTitle: String = {
            if let spineHref = spine.href {
                return hrefToTitle[spineHref]
            }
            return nil
        } () ?? "Unknow"
        
        guard let publicationID = navigator.publication.metadata.identifier else {return}
        
      let bookmark = Bookmark(resourceHref: spine.href!, resourceIndex: resourceIndex, progression: progression, resourceTitle: spineTitle, publicationID: publicationID)
      
      if (bookmarksDataSource?.addBookmark(bookmark: bookmark) ?? false) {
        toast(self.view, "Bookmark Added", 1)
      } else {
        toast(self.view, "Could not add Bookmark", 2)
      }
      
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
        
      
        /// Set initial UI appearance.
        if let appearance = navigator.publication.userProperties.getProperty(reference: ReadiumCSSReference.appearance.rawValue) {
            setUIColor(for: appearance)
        }
        
        userSettingNavigationController.modalPresentationStyle = .popover
        userSettingNavigationController.usdelegate = self
        
        fixedTopBar.delegate = self
        fixedBottomBar.delegate = self
        navigator.delegate = self
        
        let userSettings = navigator.userSettings
        userSettingNavigationController.userSettings = userSettings
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fixedTopBar.setLabel(title: navigator.publication.metadata.title)
        fixedBottomBar.setLabel(title: "")
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        var barButtons = [UIBarButtonItem]()
        
        // SpineItemView button.
        let spineItemButton = UIBarButtonItem(image: #imageLiteral(resourceName: "menuIcon"), style: .plain, target: self,
                                              action: #selector(presentTableOfContents))
        barButtons.append(spineItemButton)
      
        // User configuration button
        let userSettingsButton = UIBarButtonItem(image: #imageLiteral(resourceName: "settingsIcon"), style: .plain, target: self,
                                                 action: #selector(presentUserSettings))
        barButtons.append(userSettingsButton)
        
        if drm != nil {
            let drmManagementButton = UIBarButtonItem(image: #imageLiteral(resourceName: "drm"), style: .plain, target: self,
                                                      action: #selector(presentDrmManagement))
            barButtons.append(drmManagementButton)
        }
        
        barButtons.append(self.bookmarkButton)
        
        popoverUserconfigurationAnchor = userSettingsButton
        /// Add spineItemViewController button to navBar.
        navigationItem.setRightBarButtonItems(barButtons,
                                              animated: true)
        
        
       
        self.userSettingNavigationController.userSettingsTableViewController.publication = navigator.publication
        
        self.navigator.publication.userSettingsUIPresetUpdated = { (thisUserSettingsUIPreset) in
            
            guard let presetScrollValue:Bool = thisUserSettingsUIPreset?[.scroll] else {return}
            
            if let scroll = self.userSettingNavigationController.userSettings.userProperties.getProperty(reference: ReadiumCSSReference.scroll.rawValue) as? Switchable {
                if scroll.on != presetScrollValue {
                    self.userSettingNavigationController.scrollModeDidChange()
                }
            }
        }
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
        
        userSettingNavigationController.publication = self.navigator.publication
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
        
        moduleDelegate?.presentOutline(navigator.getTableOfContents(), type: .epub, delegate: self, from: self)
    }
    
    @objc func presentDrmManagement() {
        guard let drm = drm else {
            return
        }
        
        // Dismiss userSettings if opened.
        if let userSettingsTVC = userSettingNavigationController.userSettingsTableViewController {
            userSettingsTVC.dismiss(animated: true, completion: nil)
        }
        
        moduleDelegate?.presentDRM(drm, from: self)
    }
}

extension EpubViewController: OutlineTableViewControllerDelegate {
    
    func outline(_ outlineTableViewController: OutlineTableViewController, didSelectItem item: String) {
        _ = navigator.displaySpineItem(with: item)
    }
    
    func outline(_ outlineTableViewController: OutlineTableViewController, didSelectBookmark bookmark: Bookmark) {
        navigator.displaySpineItem(at: bookmark.resourceIndex, progression: bookmark.progression)
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
        
        // FIXME:
//        drmManagementTVC?.appearance = appearance
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
