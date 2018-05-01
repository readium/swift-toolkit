//
//  UserSettingsNavigationController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 9/28/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit
import R2Navigator

protocol UserSettingsNavigationControllerDelegate: class {
    func getUserSettings() -> UserSettings
    func updateUserSettingsStyle()
    func setUIColor(for appearance: UserSettings.Appearance)
    func toggleFixedBars()
}

internal class UserSettingsNavigationController: UINavigationController {
    var userSettingsTableViewController: UserSettingsTableViewController!
    //
    var fontSelectionViewController: FontSelectionViewController!
    var advancedSettingsViewController: AdvancedSettingsViewController!
    //
    weak var usdelegate: UserSettingsNavigationControllerDelegate!
    var userSettings: UserSettings!

    override func viewDidLoad() {
        super.viewDidLoad()
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        userSettings = usdelegate.getUserSettings()

        userSettingsTableViewController = viewControllers[0] as! UserSettingsTableViewController
        
        fontSelectionViewController =
            storyboard.instantiateViewController(withIdentifier: "FontSelectionViewController") as! FontSelectionViewController
        advancedSettingsViewController =
            storyboard.instantiateViewController(withIdentifier: "AdvancedSettingsViewController") as! AdvancedSettingsViewController

        userSettingsTableViewController.modalPresentationStyle = .popover
        userSettingsTableViewController.delegate = self
        userSettingsTableViewController.userSettings = userSettings
        //
        fontSelectionViewController.delegate = self
        advancedSettingsViewController.delegate = self
        advancedSettingsViewController.userSettings = userSettings
    }
    
    func publisherSettingsDidChange(to state: Bool) {
        userSettings?.publisherSettings = state
        usdelegate?.updateUserSettingsStyle()
    }
}

// MARK: - Delegate of the UserSettingsView Controller.
extension UserSettingsNavigationController: UserSettingsDelegate {
    func fontSizeDidChange(to sizeString: String) {
        userSettings.fontSize = sizeString
        usdelegate?.updateUserSettingsStyle()
    }

    func appearanceDidChange(to appearance: UserSettings.Appearance) {
        userSettings.appearance = appearance
        usdelegate?.updateUserSettingsStyle()
        // Change view appearance.
        usdelegate?.setUIColor(for: appearance)
    }

    func scrollDidChange(to scroll: UserSettings.Scroll) {
        // remove snap in nav TODO -- taps etc, fix all
        userSettings.scroll = scroll
        usdelegate?.updateUserSettingsStyle()
        usdelegate?.toggleFixedBars()
    }

    func getFontSelectionViewController() -> FontSelectionViewController {
        return fontSelectionViewController
    }

    func getAdvancedSettingsViewController() -> AdvancedSettingsViewController {
        return advancedSettingsViewController
    }
}

// Delegate of the Font Selection View Controller.
extension UserSettingsNavigationController: FontSelectionDelegate {
    func currentFont() -> UserSettings.Font? {
        return userSettings.font
    }

    func fontDidChange(to font: UserSettings.Font) {
        userSettings.font = font
        userSettingsTableViewController.setSelectedFontLabel(to: font.name())
        usdelegate?.updateUserSettingsStyle()
    }
}

// Delegate for the Advanced Settings View Controller.
extension UserSettingsNavigationController: AdvancedSettingsDelegate {

    func textAlignementDidChange(to textAlignement: UserSettings.TextAlignement) {
        userSettings.textAlignement = textAlignement
        usdelegate?.updateUserSettingsStyle()
    }

    /// Word Spacing.

    func incrementWordSpacing() {
        userSettings.wordSpacing.increment()
        usdelegate?.updateUserSettingsStyle()
    }

    func decrementWordSpacing() {
        userSettings.wordSpacing.decrement()
        usdelegate?.updateUserSettingsStyle()
    }

    func updateWordSpacingLabel() {
        let newValue = userSettings.wordSpacing.stringValue()

        advancedSettingsViewController.updateWordSpacing(value: newValue)
    }

    /// Letter spacing.

    func incrementLetterSpacing() {
        userSettings.letterSpacing.increment()
        usdelegate?.updateUserSettingsStyle()
    }

    func decrementLetterSpacing() {
        userSettings.letterSpacing.decrement()
        usdelegate?.updateUserSettingsStyle()
    }

    func updateLetterSpacingLabel() {
        let newValue = userSettings.letterSpacing.stringValue()

        advancedSettingsViewController.updateLetterSpacing(value: newValue)
    }

    func columnCountDidChange(to columnCount: UserSettings.ColumnCount) {
        userSettings.columnCount = columnCount
        usdelegate?.updateUserSettingsStyle()
    }

    func incrementPageMargins() {
        userSettings.pageMargins.increment()
        usdelegate?.updateUserSettingsStyle()
    }

    func decrementPageMargins() {
        userSettings.pageMargins.decrement()
        usdelegate?.updateUserSettingsStyle()
    }

    func updatePageMarginsLabel() {
        let newValue = userSettings.pageMargins.stringValue()

        advancedSettingsViewController.updatePageMargins(value: newValue)
    }
}
