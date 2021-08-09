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
    private let fontFamilyValues = ["Original", "Helvetica Neue", "Iowan Old Style", "Athelas", "Seravek", "OpenDyslexic", "AccessibleDfA", "IA Writer Duospace"]
    private let textAlignmentValues = ["justify", "start"]
    private let columnCountValues = ["auto", "1", "2"]
    
    private var fontSize: Float
    private var fontOverride: Bool
    private var fontFamily: Int
    private var appearance: Int
    private var verticalScroll: Bool
    private var hyphens: Bool
    
    private var publisherDefaults: Bool
    private var textAlignment: Int
    private var columnCount: Int
    private var wordSpacing: Float
    private var letterSpacing: Float
    private var pageMargins: Float
    private var lineHeight: Float
    private var paragraphMargins: Float?
    
    public let userProperties = UserProperties()
    
    private let userDefaults = UserDefaults.standard

    /// Designated initializer.
    ///
    /// - Important: For each parameter, if a corresponding value is found in
    /// `UserDefaults`, that value will be used instead of the passed-in value.
    ///
    /// - Note: When VoiceOver is enabled, depending on how the EPUB is
    /// formatted, moving to the next paragraph (swipe right) may bring
    /// the reading point to the end of the chapter instead of the next
    /// paragraph. This is a bug in WKWebView that can be worked around
    /// by setting the `paragraphMargins` parameter to 0.5 or more.
    ///
    /// - Parameters:
    ///   - hyphens: Whether words should be hyphenated by default.
    ///   - fontSize: The default font size as a `%` value.
    ///   - fontFamily: Index for the default font family. The list of font
    ///   families is configurable by adding/removing objects matching
    ///   `ReadiumCSSReference.fontFamily` in the `userProperties` property.
    ///   - appearance: Index for the default appearance. The list of
    ///  appearances is configurable by adding/removing objects matching
    ///   `ReadiumCSSReference.appearance` in the `userProperties` property.
    ///   - verticalScroll: Whether vertical scroll should be enabled by default.
    ///   - publisherDefaults: Whether the publisher's EPUB formatting choices
    ///   should be enabled by default.
    ///   - textAlignment: Index for the default text alignment. The list of
    ///  usable alignments is configurable by adding/removing objects matching
    ///   `ReadiumCSSReference.textAlignment` in the `userProperties` property.
    ///   - columnCount: Index for the default column count. The list of
    ///  usable values is configurable by adding/removing objects matching
    ///   `ReadiumCSSReference.columnCount` in the `userProperties` property.
    ///   - wordSpacing: The default word spacing as an `em` value.
    ///   - letterSpacing: The default letter spacing as a `rem` value.
    ///   - pageMargins: The default page margin value.
    ///   - lineHeight: The default line height.
    ///   - paragraphMargins: The default margin top and bottom `em` value to
    ///   separate paragraphs. Passing `nil` will prevent Readium to forcibly
    ///   modify paragraph spacing, ignoring what was previously set in
    ///   UserDefaults. For most EPUBs, in order for this setting to work
    ///   it may be required that `publisherDefaults` is set to `false`.
    public init(
        hyphens: Bool = false,
        fontSize: Float = 100,
        fontFamily: Int = 0,
        appearance: Int = 0,
        verticalScroll: Bool = false,
        publisherDefaults: Bool = true,
        textAlignment: Int = 0,
        columnCount: Int = 0,
        wordSpacing: Float = 0,
        letterSpacing: Float = 0,
        pageMargins: Float = 1,
        lineHeight: Float = 1.5,
        paragraphMargins: Float? = nil
    ) {

        /// Check if a given key is set in the UserDefaults.
        func isKeyPresentInUserDefaults(key: ReadiumCSSName) -> Bool {
            UserDefaults.standard.object(forKey: key.rawValue) != nil
        }

        /// Load settings from UserDefaults
        
        // hyphens
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.hyphens) {
            self.hyphens = userDefaults.bool(forKey: ReadiumCSSName.hyphens.rawValue)
        } else {
            self.hyphens = hyphens
        }
        
        // Font size
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.fontSize) {
            self.fontSize = userDefaults.float(forKey: ReadiumCSSName.fontSize.rawValue)
        } else {
            self.fontSize = fontSize
        }

        // Font family
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.fontFamily) {
            self.fontFamily = userDefaults.integer(forKey: ReadiumCSSName.fontFamily.rawValue)
        } else {
            self.fontFamily = fontFamily
        }
        
        // Font override
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.fontOverride) {
            self.fontOverride = userDefaults.bool(forKey: ReadiumCSSName.fontOverride.rawValue)
        } else {
            self.fontOverride = (fontFamily != 0)
        }
        
        // Appearance
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.appearance) {
            self.appearance = userDefaults.integer(forKey: ReadiumCSSName.appearance.rawValue)
        } else {
            self.appearance = appearance
        }
        
        // Vertical scroll
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.scroll) {
            self.verticalScroll = userDefaults.bool(forKey: ReadiumCSSName.scroll.rawValue)
        } else {
            self.verticalScroll = verticalScroll
        }
        
        // Publisher default system
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.publisherDefault) {
            self.publisherDefaults = userDefaults.bool(forKey: ReadiumCSSName.publisherDefault.rawValue)
        } else {
            self.publisherDefaults = publisherDefaults
        }
        
        // Text alignment
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.textAlignment) {
            self.textAlignment = userDefaults.integer(forKey: ReadiumCSSName.textAlignment.rawValue)
        } else {
            self.textAlignment = textAlignment
        }
        
        // Column count
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.columnCount) {
            self.columnCount = userDefaults.integer(forKey: ReadiumCSSName.columnCount.rawValue)
        } else {
            self.columnCount = columnCount
        }
        
        // Word spacing
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.wordSpacing) {
            self.wordSpacing = userDefaults.float(forKey: ReadiumCSSName.wordSpacing.rawValue)
        } else {
            self.wordSpacing = wordSpacing
        }
        
        // Letter spacing
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.letterSpacing) {
            self.letterSpacing = userDefaults.float(forKey: ReadiumCSSName.letterSpacing.rawValue)
        } else {
            self.letterSpacing = letterSpacing
        }
        
        // Page margins
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.pageMargins) {
            self.pageMargins = userDefaults.float(forKey: ReadiumCSSName.pageMargins.rawValue)
        } else {
            self.pageMargins = pageMargins
        }
        
        // Line height
        if isKeyPresentInUserDefaults(key: ReadiumCSSName.lineHeight) {
            self.lineHeight = userDefaults.float(forKey: ReadiumCSSName.lineHeight.rawValue)
        } else {
            self.lineHeight = lineHeight
        }
        
        // Paragraph Margins
        // A nil `paragraphMargins` input parameter provides a way for client
        // apps to opt out of setting a value for paragraph spacing, which is
        // something that may not always be desirable. A use case is using
        // this parameter to work around WKWebView bugs with VoiceOver
        // (e.g. https://github.com/readium/r2-navigator-swift/issues/197 )
        // but when VoiceOver is not active it may be desirable to not change
        // paragraph spacing at all.
        if paragraphMargins != nil, isKeyPresentInUserDefaults(key: ReadiumCSSName.paragraphMargins) {
            self.paragraphMargins = userDefaults.float(forKey: ReadiumCSSName.paragraphMargins.rawValue)
        } else {
            self.paragraphMargins = paragraphMargins
        }

        buildCssProperties()
        
    }
    
    // Build and add CSS properties
    private func buildCssProperties() {
        
        // Hyphens
        userProperties.addSwitchable(onValue: "auto",
                                     offValue: "none",
                                     on: hyphens,
                                     reference: ReadiumCSSReference.hyphens.rawValue,
                                     name: ReadiumCSSName.hyphens.rawValue)
        
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
        
        // Paragraph margins
        if let paragraphMargins = paragraphMargins {
            userProperties.addIncrementable(nValue: paragraphMargins,
                                            min: 0,
                                            max: 2,
                                            step: 0.1,
                                            suffix: "em",
                                            reference: ReadiumCSSReference.paragraphMargins.rawValue,
                                            name: ReadiumCSSName.paragraphMargins.rawValue)
        }
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

        if let currentParagraphMargins = userProperties.getProperty(reference: ReadiumCSSReference.paragraphMargins.rawValue) as? Incrementable {
            userDefaults.set(currentParagraphMargins.value, forKey: ReadiumCSSName.paragraphMargins.rawValue)
        }
        
    }

}
