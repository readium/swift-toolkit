//
//  UserSettingsNavigationController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 9/28/17.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Navigator
import R2Shared

protocol UserSettingsNavigationControllerDelegate: AnyObject {
    func getUserSettings() -> UserSettings
    func updateUserSettingsStyle()
    func setUIColor(for appearance: UserProperty)
}

internal class UserSettingsNavigationController: UINavigationController {

    weak var usdelegate: UserSettingsNavigationControllerDelegate!
    var userSettings: UserSettings!
    weak var publication: Publication?

    var fontSelectionViewController: FontSelectionViewController!
    var advancedSettingsViewController: AdvancedSettingsViewController!
    var userSettingsTableViewController: UserSettingsTableViewController! {
        return findChildViewController()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        userSettings = usdelegate.getUserSettings()
        
        userSettingsTableViewController.modalPresentationStyle = .popover
        userSettingsTableViewController.delegate = self
        userSettingsTableViewController.userSettings = userSettings
        
        fontSelectionViewController.delegate = self
        fontSelectionViewController.userSettings = userSettings
        advancedSettingsViewController.delegate = self
        advancedSettingsViewController.userSettings = userSettings
        advancedSettingsViewController.publication = publication
    }
    
    /// Publisher's default
    
    func publisherSettingsDidChange() {
        if let publisherDefault = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.publisherDefault.rawValue) as? Switchable {
            publisherDefault.switchValue()
            usdelegate?.updateUserSettingsStyle()
        }
    }
}

// MARK: - Delegate of the UserSettingsView Controller.
extension UserSettingsNavigationController: UserSettingsDelegate {
    
    /// Font size
    
    func fontSizeDidChange(increase: Bool) {
        if let fontSize = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.fontSize.rawValue) as? Incrementable {
            if increase {
                fontSize.increment()
            } else {
                fontSize.decrement()
            }
            usdelegate?.updateUserSettingsStyle()
        }
    }
    
    /// Appearance

    func appearanceDidChange(to appearanceIndex: Int) {
        if let appearance = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.appearance.rawValue) as? Enumerable {
            appearance.index = appearanceIndex
            usdelegate?.updateUserSettingsStyle()
            // Change view appearance.
            usdelegate?.setUIColor(for: appearance)
        }
    }

    /// Vertical scroll
    
    func scrollModeDidChange() {
        if let scroll = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.scroll.rawValue) as? Switchable {
            scroll.switchValue()
            usdelegate?.updateUserSettingsStyle()
        }
    }

    /// Font family
    
    func getFontSelectionViewController() -> FontSelectionViewController {
        return fontSelectionViewController
    }

    /// Advanced settings
    func getAdvancedSettingsViewController() -> AdvancedSettingsViewController {
        return advancedSettingsViewController
    }
    
}

// Delegate of the Font Selection View Controller.
extension UserSettingsNavigationController: FontSelectionDelegate {
    func currentFontIndex() -> Int {
        if let fontFamily = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.fontFamily.rawValue) as? Enumerable {
            return fontFamily.index
        } else {
            return 0
        }
    }

    func fontDidChange(to fontIndex: Int) {
        if let fontFamily = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.fontFamily.rawValue) as? Enumerable,
            let fontOverride = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.fontOverride.rawValue) as? Switchable {
            fontFamily.index = fontIndex
            if fontFamily.index != 0 {
                fontOverride.on = true
            } else {
                fontOverride.on = false
            }
            userSettingsTableViewController.setSelectedFontLabel(to: fontFamily.toString())
            usdelegate?.updateUserSettingsStyle()
        }
    }
}

// Delegate for the Advanced Settings View Controller.
extension UserSettingsNavigationController: AdvancedSettingsDelegate {
    
    /// Text alignment
    
    func textAlignementDidChange(to textAlignmentIndex: Int) {
        if let textAlignment = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.textAlignment.rawValue) as? Enumerable {
            textAlignment.index = textAlignmentIndex
            usdelegate?.updateUserSettingsStyle()
        }
    }

    /// Word spacing
    func incrementWordSpacing() {
        if let wordSpacing = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.wordSpacing.rawValue) as? Incrementable {
            wordSpacing.increment()
            usdelegate?.updateUserSettingsStyle()
        }
    }

    func decrementWordSpacing() {
        if let wordSpacing = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.wordSpacing.rawValue) as? Incrementable {
            wordSpacing.decrement()
            usdelegate?.updateUserSettingsStyle()
        }
    }

    func updateWordSpacingLabel() {
        if let newValue = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.wordSpacing.rawValue)?.toString() {
            advancedSettingsViewController.updateWordSpacing(value: newValue)
        }
    }

    /// Letter spacing

    func incrementLetterSpacing() {
        if let letterSpacing = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.letterSpacing.rawValue) as? Incrementable {
            letterSpacing.increment()
            usdelegate?.updateUserSettingsStyle()
        }
    }

    func decrementLetterSpacing() {
        if let letterSpacing = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.letterSpacing.rawValue) as? Incrementable {
            letterSpacing.decrement()
            usdelegate?.updateUserSettingsStyle()
        }
    }

    func updateLetterSpacingLabel() {
        if let newValue = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.letterSpacing.rawValue)?.toString() {
            advancedSettingsViewController.updateLetterSpacing(value: newValue)
        }
    }
    
    /// Column count

    func columnCountDidChange(to columnCountIndex: Int) {
        if let columnCount = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.columnCount.rawValue) as? Enumerable {
            columnCount.index = columnCountIndex
            usdelegate?.updateUserSettingsStyle()
        }
    }
    
    /// Page margins

    func incrementPageMargins() {
        if let pageMargins = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.pageMargins.rawValue) as? Incrementable {
            pageMargins.increment()
            usdelegate?.updateUserSettingsStyle()
        }
    }

    func decrementPageMargins() {
        if let pageMargins = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.pageMargins.rawValue) as? Incrementable {
            pageMargins.decrement()
            usdelegate?.updateUserSettingsStyle()
        }
    }

    func updatePageMarginsLabel() {
        if let newValue = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.pageMargins.rawValue)?.toString() {
            advancedSettingsViewController.updatePageMargins(value: newValue)
        }
    }
    
    /// Line height
    
    func incrementLineHeight() {
        if let lineHeight = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.lineHeight.rawValue) as? Incrementable {
            lineHeight.increment()
            usdelegate?.updateUserSettingsStyle()
        }
    }
    
    func decrementLineHeight() {
        if let lineHeight = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.lineHeight.rawValue) as? Incrementable {
            lineHeight.decrement()
            usdelegate?.updateUserSettingsStyle()
        }
    }
    
    func updateLineHeightLabel() {
        if let newValue = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.lineHeight.rawValue)?.toString() {
            advancedSettingsViewController.updateLineHeight(value: newValue)
        }
    }
    
}
