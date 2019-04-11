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
        navigator = EPUBNavigatorViewController(for: publication, license: drm?.license, initialIndex: index, initialProgression: progression)
        
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
        userSettingNavigationController.userSettingsTableViewController.publication = navigator.publication
        
        fixedTopBar.setLabel(title: navigator.publication.metadata.title)
        fixedBottomBar.setLabel(title: "")
        

        navigator.publication.userSettingsUIPresetUpdated = { [weak self] preset in
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
    
    override func willPresentViewController() {
        // Dismiss userSettings if opened.
        if let userSettingsTVC = userSettingNavigationController.userSettingsTableViewController {
            userSettingsTVC.dismiss(animated: true, completion: nil)
        }
    }
    
    override func presentOutline() {
      willPresentViewController()
      super.presentOutline()
    }
  
    override func bookmarkCurrentPosition() {
      willPresentViewController()
      super.bookmarkCurrentPosition()
    }
  
    override func makeNavigationBarButtons() -> [UIBarButtonItem] {
        var buttons = super.makeNavigationBarButtons()

        if drm != nil {
            let drmManagementButton = UIBarButtonItem(image: #imageLiteral(resourceName: "drm"), style: .plain, target: self, action: #selector(presentDrmManagement))
            buttons.insert(drmManagementButton, at: 1)
        }
        
        // User configuration button
        let userSettingsButton = UIBarButtonItem(image: #imageLiteral(resourceName: "settingsIcon"), style: .plain, target: self, action: #selector(presentUserSettings))
        buttons.insert(userSettingsButton, at: 1)
        popoverUserconfigurationAnchor = userSettingsButton
        
        return buttons
    }
    
    override var currentBookmark: Bookmark? {
        guard let publicationID = publication.metadata.identifier,
            let locator = navigator.currentLocation,
            let resourceIndex = publication.readingOrder.firstIndex(withHref: locator.href) else
        {
            return nil
        }
        return Bookmark(publicationID: publicationID, resourceIndex: resourceIndex, locator: locator)
    }
    
    override func goTo(item: String) {
        _ = navigator.displayReadingOrderItem(with: item)
    }
    
    override func goTo(bookmark: Bookmark) {
        navigator.displayReadingOrderItem(at: bookmark.resourceIndex, progression: bookmark.locator.locations?.progression ?? 0)
    }

    @objc func presentUserSettings() {
        let popoverPresentationController = userSettingNavigationController.popoverPresentationController!
        
        popoverPresentationController.delegate = self
        popoverPresentationController.barButtonItem = popoverUserconfigurationAnchor
        
        userSettingNavigationController.publication = self.navigator.publication
        present(userSettingNavigationController, animated: true, completion: nil)
    }
    
    @objc func presentDrmManagement() {
        guard let drm = drm else {
            return
        }
        
        willPresentViewController()
        moduleDelegate?.presentDRM(drm, from: self)
    }
    
}

extension EPUBViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
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
        moduleDelegate?.presentError(error, from: self)
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
