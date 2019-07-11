//
//  UserSettings.swift
//  r2-navigator-swift
//
//  Created by Alexandre Camilleri on 8/25/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit

import R2Shared

public class UserSettings {
    
    // WARNING: String values must not contain any single or double quotes characters, otherwise it breaks the streamer's injection.
    private let appearanceValues = ["readium-default-on", "readium-sepia-on","readium-night-on"]
    private let fontFamilyValues = ["Original", "Helvetica Neue", "Iowan Old Style", "Athelas", "Seravek", "OpenDyslexic"]
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
    private var lineHeight: Float = 1
    
    public let userProperties = UserProperties()
    
    private let userDefaults = UserDefaults.standard

    internal init() {
        
        /// Load settings from UserDefaults
        
        // Font size
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.fontSize) {
            fontSize = userDefaults.float(forKey: ReadiumCSSName.fontSize.rawValue)
        } else {
            fontSize = 100
        }

        // Font family
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.fontFamily) {
            fontFamily = userDefaults.integer(forKey: ReadiumCSSName.fontFamily.rawValue)
        } else {
            fontFamily = 0
        }
        
        // Font override
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.fontOverride) {
            fontOverride = userDefaults.bool(forKey: ReadiumCSSName.fontOverride.rawValue)
        } else if fontFamily != 0 {
            fontOverride = true
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
            pageMargins = 1
        }
        
        // Line height
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.lineHeight) {
            lineHeight = userDefaults.float(forKey: ReadiumCSSName.lineHeight.rawValue)
        } else {
            lineHeight = 1
        }
        
        buildCssProperties()
        
    }
    
    // Build and add CSS properties
    private func buildCssProperties() {
        
        // Font size
        userProperties.addIncrementable(nValue: fontSize,
                                        min: 100,
                                        max: 300,
                                        step: 25,
                                        suffix: "%",
                                        reference: ReadiumCSSReference.fontSize.rawValue,
                                        name: ReadiumCSSName.fontSize.rawValue)
        
        // Font family
        userProperties.addEnumerable(index: fontFamily,
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
        
        // Line height
        userProperties.addIncrementable(nValue: lineHeight,
                                        min: 1,
                                        max: 2,
                                        step: 0.25,
                                        suffix: "",
                                        reference: ReadiumCSSReference.lineHeight.rawValue,
                                        name: ReadiumCSSName.lineHeight.rawValue)
        
    }
    
    // Save settings to UserDefaults
    public func save() {
        
        let userDefaults = UserDefaults.standard

        if let currentfontSize = userProperties.getProperty(reference: ReadiumCSSReference.fontSize.rawValue) as? Incrementable {
            userDefaults.set(currentfontSize.value, forKey: ReadiumCSSName.fontSize.rawValue)
        }
        
        if let currentfontFamily = userProperties.getProperty(reference: ReadiumCSSReference.fontFamily.rawValue) as? Enumerable {
            userDefaults.set(currentfontFamily.index, forKey: ReadiumCSSName.fontFamily.rawValue)
        }
        
        if let currentfontOverride = userProperties.getProperty(reference: ReadiumCSSReference.fontOverride.rawValue) as? Switchable {
            userDefaults.set(currentfontOverride.on, forKey: ReadiumCSSName.fontOverride.rawValue)
        }
        
        if let currentAppearance = userProperties.getProperty(reference: ReadiumCSSReference.appearance.rawValue) as? Enumerable {
            userDefaults.set(currentAppearance.index, forKey: ReadiumCSSName.appearance.rawValue)
        }
        
        if let currentVerticalScroll = userProperties.getProperty(reference: ReadiumCSSReference.scroll.rawValue) as? Switchable {
            userDefaults.set(currentVerticalScroll.on, forKey: ReadiumCSSName.scroll.rawValue)
        }
        
        if let currentPublisherDefaults = userProperties.getProperty(reference: ReadiumCSSReference.publisherDefault.rawValue) as? Switchable {
            userDefaults.set(currentPublisherDefaults.on, forKey: ReadiumCSSName.publisherDefault.rawValue)
        }

        if let currentTextAlignment = userProperties.getProperty(reference: ReadiumCSSReference.textAlignment.rawValue) as? Enumerable {
            userDefaults.set(currentTextAlignment.index, forKey: ReadiumCSSName.textAlignment.rawValue)
        }
        
        if let currentColumnCount = userProperties.getProperty(reference: ReadiumCSSReference.columnCount.rawValue) as? Enumerable {
            userDefaults.set(currentColumnCount.index, forKey: ReadiumCSSName.columnCount.rawValue)
        }
        
        if let currentWordSpacing = userProperties.getProperty(reference: ReadiumCSSReference.wordSpacing.rawValue) as? Incrementable {
            userDefaults.set(currentWordSpacing.value, forKey: ReadiumCSSName.wordSpacing.rawValue)
        }
        
        if let currentLetterSpacing = userProperties.getProperty(reference: ReadiumCSSReference.letterSpacing.rawValue) as? Incrementable {
            userDefaults.set(currentLetterSpacing.value, forKey: ReadiumCSSName.letterSpacing.rawValue)
        }
        
        if let currentPageMargins = userProperties.getProperty(reference: ReadiumCSSReference.pageMargins.rawValue) as? Incrementable {
            userDefaults.set(currentPageMargins.value, forKey: ReadiumCSSName.pageMargins.rawValue)
        }
        
        if let currentLineHeight = userProperties.getProperty(reference: ReadiumCSSReference.lineHeight.rawValue) as? Incrementable {
            userDefaults.set(currentLineHeight.value, forKey: ReadiumCSSName.lineHeight.rawValue)
        }
        
    }
    
    /// Check if a given key is set in the UserDefaults.
    ///
    /// - Parameter key: The key name.
    /// - Returns: A boolean value indicating if the value is present.
    private func isKeyPresentInUserDefaults(key: ReadiumCSSName) -> Bool {
        return UserDefaults.standard.object(forKey: key.rawValue) != nil
    }
    
}
