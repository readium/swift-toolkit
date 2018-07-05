//
//  UserSettings.swift
//  r2-navigator-swift
//
//  Created by Alexandre Camilleri on 8/25/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import UIKit

import R2Shared

public class UserSettings {
    
    private let appearanceValues = ["readium-default-on", "readium-sepia-on","readium-night-on"]
    private let fontFamilyValues = ["Publisher's default", "Helvetica Neue", "Iowan Old Style", "Athelas", "Seravek"]
    private let textAlignmentValues = ["justify", "start"]
    private let columnCountValues = ["auto", "1", "2"]
    
    private var fontSize: Float = 100
    private var fontOverride = false
    private var fontFamily = 0
    private var appearance = 0
    private var verticalScroll = false
    
    private var publisherDefaults = false
    private var textAlignment = 0
    private var columnCount = 0
    private var wordSpacing: Float = 0
    private var letterSpacing: Float = 0
    private var pageMargins: Float = 1
    
    public var userSettingsUIPreset: [ReadiumCSSName: Bool]?

    internal init() {
        
        let userDefaults = UserDefaults.standard

        /// Load settings from UserDefaults
        
        // Font size
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.fontSize) {
            fontSize = userDefaults.float(forKey: ReadiumCSSName.fontSize.rawValue)
        } else {
            fontSize = 100
        }

        // Font family
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.fontFamily) {
            fontFamily = userDefaults.integer(forKey: ReadiumCSSName.fontSize.rawValue)
        } else {
            fontFamily = 0
        }
        
        // Font override
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.fontOverride) {
            fontOverride = userDefaults.bool(forKey: ReadiumCSSName.fontOverride.rawValue)
        } else {
            fontOverride = false
        }
        
        // Appearance
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.appearance) {
            appearance = userDefaults.integer(forKey: ReadiumCSSName.appearance.rawValue)
        } else {
            appearance = 0
        }
        
        // Vertical scroll
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.scroll) {
            verticalScroll = userDefaults.bool(forKey: ReadiumCSSName.scroll.rawValue)
        } else {
            verticalScroll = false
        }
        
        // Publisher default system
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.publisherDefault) {
            publisherDefaults = userDefaults.bool(forKey: ReadiumCSSName.publisherDefault.rawValue)
        } else {
            publisherDefaults = false
        }
        
        // Text alignment
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.textAlignment) {
            textAlignment = userDefaults.integer(forKey: ReadiumCSSName.textAlignment.rawValue)
        } else {
            textAlignment = 0
        }
        
        // Column count
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.columnCount) {
            columnCount = userDefaults.integer(forKey: ReadiumCSSName.columnCount.rawValue)
        } else {
            columnCount = 0
        }
        
        // Word spacing
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.wordSpacing) {
            wordSpacing = userDefaults.float(forKey: ReadiumCSSName.wordSpacing.rawValue)
        } else {
            wordSpacing = 0
        }
        
        // Letter spacing
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.letterSpacing) {
            letterSpacing = userDefaults.float(forKey: ReadiumCSSName.letterSpacing.rawValue)
        } else {
            letterSpacing = 0
        }
        
        // Page margins
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.pageMargins) {
            pageMargins = userDefaults.float(forKey: ReadiumCSSName.pageMargins.rawValue)
        } else {
            pageMargins = 0
        }
        
    }
    
    // Get settings
    public func cssProperties() -> UserProperties {
        
        let userProperties = UserProperties()
        
        // Font size
        userProperties.addIncrementable(nValue: fontSize,
                                        min: 100,
                                        max: 300,
                                        step: 25,
                                        suffix: "%",
                                        reference: ReadiumCSSReference.fontSize.rawValue,
                                        name: ReadiumCSSName.fontSize.rawValue)
        
        // Font family
        userProperties.addEnumerable(index: 0,
                                     values: fontFamilyValues,
                                     reference: ReadiumCSSReference.fontFamily.rawValue,
                                     name: ReadiumCSSName.fontFamily.rawValue)
        
        // Font override
        userProperties.addSwitchable(onValue: "readium-font-on",
                                     offValue: "readium-font-off",
                                     on: fontOverride,
                                     reference: ReadiumCSSReference.fontOverride.rawValue,
                                     name: ReadiumCSSName.fontOverride.rawValue)
        
        // Appearance
        userProperties.addEnumerable(index: appearance,
                                     values: appearanceValues,
                                     reference: ReadiumCSSReference.appearance.rawValue,
                                     name: ReadiumCSSName.appearance.rawValue)
        
        // Vertical scroll
        userProperties.addSwitchable(onValue: "readium-scroll-on",
                                     offValue: "readium-scroll-off",
                                     on: verticalScroll,
                                     reference: ReadiumCSSReference.scroll.rawValue,
                                     name: ReadiumCSSName.scroll.rawValue)
        
        // Publisher default system
        userProperties.addSwitchable(onValue: "readium-advanced-off",
                                     offValue: "readium-advanced-on",
                                     on: publisherDefaults,
                                     reference: ReadiumCSSReference.publisherDefault.rawValue,
                                     name: ReadiumCSSName.publisherDefault.rawValue)
        
        // Text alignment
        userProperties.addEnumerable(index: textAlignment,
                                     values: textAlignmentValues,
                                     reference: ReadiumCSSReference.textAlignment.rawValue,
                                     name: ReadiumCSSName.textAlignment.rawValue)
        
        // Column count
        userProperties.addEnumerable(index: columnCount,
                                     values: columnCountValues,
                                     reference: ReadiumCSSReference.columnCount.rawValue,
                                     name: ReadiumCSSName.columnCount.rawValue)
        
        // Word spacing
        userProperties.addIncrementable(nValue: wordSpacing,
                                        min: 0,
                                        max: 0.5,
                                        step: 0.125,
                                        suffix: "rem",
                                        reference: ReadiumCSSReference.wordSpacing.rawValue,
                                        name: ReadiumCSSName.wordSpacing.rawValue)
        
        // Letter spacing
        userProperties.addIncrementable(nValue: letterSpacing,
                                        min: 0,
                                        max: 0.25,
                                        step: 0.0625,
                                        suffix: "em",
                                        reference: ReadiumCSSReference.letterSpacing.rawValue,
                                        name: ReadiumCSSName.letterSpacing.rawValue)
        
        // Page margins
        userProperties.addIncrementable(nValue: pageMargins,
                                        min: 0.5,
                                        max: 2,
                                        step: 0.25,
                                        suffix: "",
                                        reference: ReadiumCSSReference.pageMargins.rawValue,
                                        name: ReadiumCSSName.pageMargins.rawValue)
        
        return userProperties
        
    }
    
    // Save settings to UserDefaults
    public func save() {
        
        let userDefaults = UserDefaults.standard

        userDefaults.set(fontSize, forKey: ReadiumCSSName.fontSize.rawValue)
        userDefaults.set(fontFamily, forKey: ReadiumCSSName.fontFamily.rawValue)
        userDefaults.set(fontOverride, forKey: ReadiumCSSName.fontOverride.rawValue)
        userDefaults.set(appearance, forKey: ReadiumCSSName.appearance.rawValue)
        userDefaults.set(verticalScroll, forKey: ReadiumCSSName.scroll.rawValue)
        userDefaults.set(publisherDefaults, forKey: ReadiumCSSName.publisherDefault.rawValue)

        userDefaults.set(textAlignment, forKey: ReadiumCSSName.textAlignment.rawValue)
        userDefaults.set(columnCount, forKey: ReadiumCSSName.columnCount.rawValue)
        userDefaults.set(wordSpacing, forKey: ReadiumCSSName.wordSpacing.rawValue)
        userDefaults.set(letterSpacing, forKey: ReadiumCSSName.letterSpacing.rawValue)
        userDefaults.set(pageMargins, forKey: ReadiumCSSName.pageMargins.rawValue)
        
    }
    
    /// Check if a given key is set in the UserDefaults.
    ///
    /// - Parameter key: The key name.
    /// - Returns: A boolean value indicating if the value is present.
    private func isKeyPresentInUserDefaults(key: ReadiumCSSName) -> Bool {
        return UserDefaults.standard.object(forKey: key.rawValue) != nil
    }
    
}
