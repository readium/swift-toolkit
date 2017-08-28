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
    var tableOfContentsTVC: TableOfContentsTableViewController {
        return TableOfContentsTableViewController(for: navigator.getTableOfContents(),
                                                  callWhenDismissed: navigator.displaySpineItem(with:))
    }
    var popoverUserconfigurationAnchor: UIBarButtonItem?
    var userSettingsViewController: UserSettingsViewController!

    init(with publication: Publication, atIndex index: Int, progression: Double?) {
        stackView = UIStackView(frame: UIScreen.main.bounds)
        navigator = NavigatorViewController(for: publication,
                                            initialIndex: index,
                                            initialProgression: progression)
        fixedTopBar = BarView()
        fixedBottomBar = BarView()
        userSettingsViewController = UserSettingsViewController(frame: CGRect.zero,
                                                                userSettings: navigator.userSettings)
        super.init(nibName: nil, bundle: nil)
        userSettingsViewController.delegate = self
        fixedTopBar.delegate = self
        fixedBottomBar.delegate = self
        navigator.delegate = self
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        stackView.axis = .vertical
        stackView.distribution = .fill //.spacing stuff
        stackView.spacing = 10
        stackView.autoresizingMask = [.flexibleHeight, .flexibleWidth]

        stackView.addArrangedSubview(fixedTopBar)
        stackView.addArrangedSubview(navigator.view)
        stackView.addArrangedSubview(fixedBottomBar)

        view.addSubview(stackView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ////
        fixedTopBar.setLabel(title: navigator.publication.metadata.title)
        fixedBottomBar.setLabel(title: "")

        ////
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
    }

    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        navigator.userSettings.save()
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

extension EpubViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

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
        // Save current publication's document's progression.
        userDefaults.set(documentIndex, forKey: "\(publicationIdentifier)-document")
        // Save current publication's document's progression.
        userDefaults.set(progression, forKey: "\(publicationIdentifier)-documentProgression")
    }
}

extension EpubViewController {

    func presentUserSettings() {
        userSettingsViewController.modalPresentationStyle = .popover
        userSettingsViewController.preferredContentSize = CGSize(width: 250, height: 200)

        let popoverPresentationController = userSettingsViewController.popoverPresentationController!

        popoverPresentationController.delegate = self
        popoverPresentationController.barButtonItem = popoverUserconfigurationAnchor

        present(userSettingsViewController, animated: true, completion: nil)
    }

    func presentTableOfContents() {
        let backItem = UIBarButtonItem()

        backItem.title = ""
        navigationItem.backBarButtonItem = backItem
        navigationController?.pushViewController(tableOfContentsTVC, animated: true)
    }
}

extension EpubViewController: UserSettingsDelegate {
    func fontSizeDidChange(toValue: String) {
        navigator.userSettings.set(value: toValue, forKey: .fontSize)
        navigator.updateUserSettingStyle()
    }

    func appearanceDidChange(toValue: String) {
        navigator.userSettings.set(value: toValue, forKey: .appearance)
        navigator.updateUserSettingStyle()
    }
}

extension EpubViewController: UIPopoverPresentationControllerDelegate {
    // Prevent the popOver to be presented fullscreen on iPhones.
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle
    {
        return .none
    }
}
