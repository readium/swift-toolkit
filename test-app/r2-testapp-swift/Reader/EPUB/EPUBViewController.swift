//
//  EPUBViewController.swift
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

class EPUBViewController: ReaderViewController {
    
    let stackView: UIStackView!
    let navigator: EPUBNavigatorViewController!
    let fixedTopBar: BarView!
    let fixedBottomBar: BarView!
    var popoverUserconfigurationAnchor: UIBarButtonItem?
    var userSettingNavigationController: UserSettingsNavigationController

    init(publication: Publication, atIndex index: Int, progression: Double?, drm: DRM?) {
        stackView = UIStackView(frame: UIScreen.main.bounds)
        navigator = EPUBNavigatorViewController(for: publication, license: drm?.license, initialIndex: index, initialProgression: progression, editingActions: [.lookup, .copy])
        
        fixedTopBar = BarView()
        fixedBottomBar = BarView()
        
        let settingsStoryboard = UIStoryboard(name: "UserSettings", bundle: nil)
        userSettingNavigationController = settingsStoryboard.instantiateViewController(withIdentifier: "UserSettingsNavigationController") as! UserSettingsNavigationController
        userSettingNavigationController.fontSelectionViewController =
            (settingsStoryboard.instantiateViewController(withIdentifier: "FontSelectionViewController") as! FontSelectionViewController)
        userSettingNavigationController.advancedSettingsViewController =
            (settingsStoryboard.instantiateViewController(withIdentifier: "AdvancedSettingsViewController") as! AdvancedSettingsViewController)
        
        super.init(publication: publication, drm: drm)
    }

    convenience override init(publication: Publication, drm: DRM?) {
        var index: Int = 0
        var progression: Double? = nil
        
        if let identifier = publication.metadata.identifier {
            // Retrieve last read document/progression in that document.
            let userDefaults = UserDefaults.standard
            index = userDefaults.integer(forKey: "\(identifier)-document")
            progression = userDefaults.double(forKey: "\(identifier)-documentProgression")
        }
        
        self.init(publication: publication, atIndex: index, progression: progression, drm: drm)
    }

    lazy var bookmarkButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: #imageLiteral(resourceName: "bookmark"), style: .plain, target: self, action: #selector(addBookmarkForCurrentPosition))
        return button
    } ()
  
    @objc func addBookmarkForCurrentPosition() {
      if (bookmarksDataSource?.addBookmark(bookmark: navigator.currentPosition) ?? false) {
        toast(self.view, "Bookmark Added", 1)
      } else {
        toast(self.view, "Could not add Bookmark", 2)
      }
    }

    override func loadView() {
        super.loadView()
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        stackView.addArrangedSubview(fixedTopBar)
        
        addChild(navigator)
        stackView.addArrangedSubview(navigator.view)
        navigator.didMove(toParent: self)

        stackView.addArrangedSubview(fixedBottomBar)

        view.addSubview(stackView)

        fixedTopBar.delegate = self
        fixedBottomBar.delegate = self
        navigator.delegate = self
        
        let userSettings = navigator.userSettings
        userSettingNavigationController.userSettings = userSettings
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        /// Set initial UI appearance.
        if let appearance = navigator.publication.userProperties.getProperty(reference: ReadiumCSSReference.appearance.rawValue) {
            setUIColor(for: appearance)
        }
        
        userSettingNavigationController.modalPresentationStyle = .popover
        userSettingNavigationController.usdelegate = self
        
        fixedTopBar.setLabel(title: navigator.publication.metadata.title)
        fixedBottomBar.setLabel(title: "")
        
        var barButtons = [UIBarButtonItem]()
        
        // TocItemView button.
        let tocItemButton = UIBarButtonItem(image: #imageLiteral(resourceName: "menuIcon"), style: .plain, target: self,
                                              action: #selector(presentTableOfContents))
        barButtons.append(tocItemButton)
      
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
        /// Add tocItemViewController button to navBar.
        navigationItem.setRightBarButtonItems(barButtons, animated: true)
       
        self.userSettingNavigationController.userSettingsTableViewController.publication = navigator.publication
        
        self.navigator.publication.userSettingsUIPresetUpdated = { [weak self] preset in
            guard let `self` = self, let presetScrollValue:Bool = preset?[.scroll] else {
                return
            }
            
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
        
        toggleFixedBars()
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        navigator.userSettings.save()
    }
    
    override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        fixedTopBar.setNeedsUpdateConstraints()
        fixedBottomBar.setNeedsUpdateConstraints()
    }
}

extension EPUBViewController {
    
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
        
        moduleDelegate?.presentOutline(publication.toc, type: .epub, delegate: self, from: self)
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

extension EPUBViewController: OutlineTableViewControllerDelegate {
    
    func outline(_ outlineTableViewController: OutlineTableViewController, didSelectItem item: String) {
        _ = navigator.displayReadingOrderItem(with: item)
    }
    
    func outline(_ outlineTableViewController: OutlineTableViewController, didSelectBookmark bookmark: Bookmark) {
        navigator.displayReadingOrderItem(at: bookmark.resourceIndex, progression: bookmark.locations!.progression!)
    }
    
}

extension EPUBViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - Delegate of the NavigatorViewController (R2Navigator).
extension EPUBViewController: EPUBNavigatorDelegate {
    
    func middleTapHandler() {
        toggleNavigationBar()
    }
    
    // The publication is being closed, provide info for saving progress.
    func willExitPublication(documentIndex: Int, progression: Double?) {
        guard let publicationIdentifier = navigator.publication.metadata.identifier else {
            return
        }
        let userDefaults = UserDefaults.standard
        // Save current publication's document's. 
        // (<=> the readingOrder item)
        userDefaults.set(documentIndex, forKey: "\(publicationIdentifier)-document")
        // Save current publication's document's progression. 
        // (<=> the position in the readingOrder item)
        userDefaults.set(progression, forKey: "\(publicationIdentifier)-documentProgression")
    }
    
    func presentError(_ error: NavigatorError) {
        let message: String = {
            switch error {
            case .copyForbidden:
                return "You are not allowed to copy the contents of this publication."
            }
        }()
        moduleDelegate?.presentAlert("Error", message: message, from: self)
    }
}

extension EPUBViewController: UserSettingsNavigationControllerDelegate {
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
        
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: colors.textColor]
        
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

extension EPUBViewController: UIPopoverPresentationControllerDelegate {
    // Prevent the popOver to be presented fullscreen on iPhones.
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle
    {
        return .none
    }
}
