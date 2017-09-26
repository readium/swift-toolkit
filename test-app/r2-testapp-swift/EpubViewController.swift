//
//  EpubViewController.swift
//  r2-navigator
//
//  Created by Alexandre Camilleri on 7/3/17.
//  Copyright © 2017 European Digital Reading Lab. All rights reserved.
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
    var userSettingsViewController: UserSettingsViewController!
    //
    var fontSelectionViewController: FontSelectionViewController!
    var advancedSettingsViewController: AdvancedSettingsViewController!

    init(with publication: Publication, atIndex index: Int, progression: Double?) {
        stackView = UIStackView(frame: UIScreen.main.bounds)
        navigator = NavigatorViewController(for: publication,
                                            initialIndex: index,
                                            initialProgression: progression)
        fixedTopBar = BarView()
        fixedBottomBar = BarView()
        tableOfContentsTVC = TableOfContentsTableViewController(for: navigator.getTableOfContents(),
                                                                callWhenDismissed: navigator.displaySpineItem(with:))
        // UserSettingsViewController.
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        userSettingsViewController =
            storyboard.instantiateViewController(withIdentifier: "UserSettingsViewController") as! UserSettingsViewController
        fontSelectionViewController =
            storyboard.instantiateViewController(withIdentifier: "FontSelectionViewController") as! FontSelectionViewController
        advancedSettingsViewController =
            storyboard.instantiateViewController(withIdentifier: "AdvancedSettingsViewController") as! AdvancedSettingsViewController
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

        /// Set initial UI appearance.
        if let appearance = navigator.userSettings.appearance {
            setUIColor(for: appearance)
        }

        // User settings windows.
        let width = UIScreen.main.bounds.width / 1.618
        let height = UIScreen.main.bounds.height / 2.1

        userSettingsViewController.preferredContentSize = CGSize(width: width, height: height)
        userSettingsViewController.modalPresentationStyle = .popover
        userSettingsViewController.delegate = self
        userSettingsViewController.userSettings = navigator.userSettings
        //
        fontSelectionViewController.modalPresentationStyle = .overCurrentContext
        advancedSettingsViewController.modalPresentationStyle = .overCurrentContext
        fontSelectionViewController.delegate = self
        advancedSettingsViewController.delegate = self

        fixedTopBar.delegate = self
        fixedBottomBar.delegate = self
        navigator.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        fixedTopBar.setLabel(title: navigator.publication.metadata.title)
        fixedBottomBar.setLabel(title: "")

        navigationController?.setNavigationBarHidden(true, animated: false)

        // SpineItemView button.
        let spineItemButton = UIBarButtonItem(image: #imageLiteral(resourceName: "menuIcon"), style: .plain, target: self,
                                              action: #selector(presentTableOfContents))
        // User configuration button

        let userSettingsButton = UIBarButtonItem(image: #imageLiteral(resourceName: "settingsIcon"), style: .plain, target: self,
                                                 action: #selector(presentUserSettings))

        popoverUserconfigurationAnchor = userSettingsButton
        /// Add spineItemViewController button to navBar.
        navigationItem.setRightBarButtonItems([spineItemButton, userSettingsButton], animated: true)
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
        return UIStatusBarAnimation.fade
    }

    open override var prefersStatusBarHidden: Bool {
        return true
    }
}

extension EpubViewController {

    func presentUserSettings() {
        let popoverPresentationController = userSettingsViewController.popoverPresentationController!

        popoverPresentationController.delegate = self
        popoverPresentationController.barButtonItem = popoverUserconfigurationAnchor

        present(userSettingsViewController, animated: true, completion: nil)
    }

    func presentTableOfContents() {
        let backItem = UIBarButtonItem()

        backItem.title = ""
        navigationItem.backBarButtonItem = backItem
        // Dismiss userSettings if opened.
        userSettingsViewController.dismiss(animated: true, completion: nil)
        self.navigationController?.pushViewController(self.tableOfContentsTVC, animated: true)
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

// MARK: - Delegate of the UserSettingsView Controller.
extension EpubViewController: UserSettingsDelegate {
    func fontSizeDidChange(to sizeString: String) {
        navigator.userSettings.set(value: sizeString, forKey: .fontSize)
        navigator.updateUserSettingStyle()
    }

    func appearanceDidChange(to appearance: UserSettings.Appearance) {
        navigator.userSettings.set(value: appearance.name(), forKey: .appearance)
        navigator.updateUserSettingStyle()
        // Change view appearance.
        setUIColor(for: appearance)
    }

    func scrollDidChange(to scroll: UserSettings.Scroll) {
        // remove snap in nav TODO -- taps etc, fix all
        navigator.userSettings.set(value: scroll.name(), forKey: UserSettings.Keys.scroll)
        navigator.updateUserSettingStyle()
        toggleFixedBars()
    }

    func publisherSettingsDidChange(to state: Bool) {
        navigator.userSettings.set(value: state.description, forKey: UserSettings.Keys.publisherSettings)
        navigator.updateUserSettingStyle()
    }

    func getFontSelectionViewController() -> FontSelectionViewController {
        return fontSelectionViewController
    }

    func getAdvancedSettingsViewController() -> AdvancedSettingsViewController {
        return advancedSettingsViewController
    }
    
    /// Synchronyze the UI appearance to the UserSettings.Appearance.
    ///
    /// - Parameter appearance: The appearance.
    fileprivate func setUIColor(for appearance: UserSettings.Appearance) {
        let color = appearance.associatedColor()
        let textColor = appearance.associatedFontColor()

        navigator.view.backgroundColor = color
        view.backgroundColor = color
        //
        navigationController?.navigationBar.barTintColor = color
        navigationController?.navigationBar.tintColor = textColor
        //
        tableOfContentsTVC.setUIColor(for: appearance)
    }

    // Toggle hide/show fixed bot and top bars.
    fileprivate func toggleFixedBars() {
        let currentValue = navigator.userSettings.scroll?.bool() ?? false

        UIView.transition(with: fixedTopBar, duration: 0.318, options: .curveEaseOut, animations: {() -> Void in
            self.fixedTopBar.isHidden = currentValue
        }, completion: nil)
        UIView.transition(with: fixedBottomBar, duration: 0.318, options: .curveEaseOut, animations: {() -> Void in
            self.fixedBottomBar.isHidden = currentValue
        }, completion: nil)
    }
}

extension EpubViewController: FontSelectionDelegate {
    func currentFont() -> UserSettings.Font? {
        return navigator.userSettings.font
    }

    func fontDidChange(to font: UserSettings.Font) {
        navigator.userSettings.set(value: font.name(), forKey: .font)
        navigator.updateUserSettingStyle()
    }
}

extension EpubViewController: AdvancedSettingsDelegate {

}

extension EpubViewController: UIPopoverPresentationControllerDelegate {
    // Prevent the popOver to be presented fullscreen on iPhones.
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle
    {
        return .none
    }
}
