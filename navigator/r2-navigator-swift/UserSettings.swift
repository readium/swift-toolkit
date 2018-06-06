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
    // FontSize in %.
    public var fontSize: String?
    public var font: Font?
    public var appearance: Appearance?
    public var scroll: Scroll?
    public var publisherSettings: Bool!
    public var textAlignement: TextAlignement!
    public var columnCount: ColumnCount!
    public var wordSpacing: WordSpacing!
    public var letterSpacing: LetterSpacing!
    public var pageMargins: PageMargins!
    
    public var hyphens: Bool!
    public var ligatures: Bool!
    
    public var userSettingsUIPreset: [ReadiumCSSKey:Bool]?

    internal init() {
        let userDefaults = UserDefaults.standard
        var value: String

        /// Load settings from userDefaults.
        // Font size.
        if isKeyPresentInUserDefaults(key: ReadiumCSSKey.fontSize) {
            fontSize = userDefaults.string(forKey: ReadiumCSSKey.fontSize.rawValue)
        } else {
            fontSize = "100"
        }

        // Font type.
        value = userDefaults.string(forKey: ReadiumCSSKey.font.rawValue) ?? ""
        font = Font.init(with: value)

        // Appearance.
        if isKeyPresentInUserDefaults(key: ReadiumCSSKey.appearance),
            let value = userDefaults.string(forKey: ReadiumCSSKey.appearance.rawValue) {
            appearance = Appearance.init(with: value)
        }

        // Scroll mod.
        value = userDefaults.string(forKey: ReadiumCSSKey.scroll.rawValue) ?? ""
        scroll = Scroll.init(with: value)

        // Publisher settings.
        publisherSettings = userDefaults.bool(forKey: ReadiumCSSKey.publisherSettings.rawValue)

        // Page Margins. (0 if unset in the userDefaults)
        let pageMarginsValue = userDefaults.double(forKey: ReadiumCSSKey.pageMargins.rawValue)

        self.pageMargins = PageMargins.init(initialValue: pageMarginsValue)

        // Text alignement.
        let textAlignement = userDefaults.integer(forKey: ReadiumCSSKey.textAlignement.rawValue)
        self.textAlignement = TextAlignement.init(with: textAlignement)
        // Word spacing.
        let wordSpacingValue = userDefaults.double(forKey: ReadiumCSSKey.wordSpacing.rawValue)
        wordSpacing = WordSpacing.init(initialValue: wordSpacingValue)

        // Letter spacing.
        let letterSpacingValue = userDefaults.double(forKey: ReadiumCSSKey.letterSpacing.rawValue)
        letterSpacing = LetterSpacing.init(initialValue: letterSpacingValue)

        // Column count.
        value = userDefaults.string(forKey: ReadiumCSSKey.columnCount.rawValue) ?? ""
        columnCount = ColumnCount.init(with: value)
        
        // hyphens and ligatures
        hyphens = userDefaults.bool(forKey: ReadiumCSSKey.hyphens.rawValue)
        ligatures = userDefaults.bool(forKey: ReadiumCSSKey.ligatures.rawValue)
    }

    public func value(forKey key: ReadiumCSSKey) -> String? {
        switch key {
        case .fontSize:
            return fontSize
        case .font:
            return font?.name()
        case .appearance:
            return appearance?.name()
        case .scroll:
            return scroll?.name()
        case .publisherSettings:
            return publisherSettings.description
        case .textAlignement:
            return textAlignement.stringValue()
        case .wordSpacing:
            return wordSpacing.stringValue()
        case .letterSpacing:
            return letterSpacing.stringValue()
        case .columnCount:
            return columnCount?.name()
        case .pageMargins:
            return pageMargins.stringValue()
        case .hyphens:
            return String(hyphens)
        case .ligatures:
            return String(ligatures)
        case .publisherFont:
            return font?.name() ?? ""
        case .paraIndent:
            return "Not supported"
        }
    }

    /// Generate an array of tuple for setting easily the CSS properties.
    ///
    /// - Returns: Css properties (key, value).
    public func cssProperties() -> [(key: String, value: String)] {
        var properties = [(key: String, value: String)]()
        var value: String

        // FontSize.
        if let fontSize = fontSize {
            properties.append((key: ReadiumCSSKey.fontSize.rawValue, "\(fontSize)%"))
        }

        // Font.
        if let font = font {
            // Do we override?
            let value = (font == .publisher ? "readium-font-off" : "readium-font-on")

            properties.append((key: ReadiumCSSKey.publisherFont.rawValue, value))
            properties.append((key: ReadiumCSSKey.font.rawValue, "\(font.name(css: true))"))
        }
        // Appearance.
        if let appearance = appearance {
            properties.append((key: ReadiumCSSKey.appearance.rawValue, "\(appearance.name())"))
        }
        // Scroll.
        if let scroll = scroll {
            properties.append((key: ReadiumCSSKey.scroll.rawValue, value: "\(scroll.name())"))
        }
        // Publisher Settings.
        value = (publisherSettings == true ? "readium-advanced-off" : "readium-advanced-on")
        properties.append((key: ReadiumCSSKey.publisherSettings.rawValue, value: "\(value)"))

        /// Advanced Settings.
        // Text alignement.
        properties.append((key: ReadiumCSSKey.textAlignement.rawValue,
                           value: textAlignement.stringValueCss()))

        // Column count.
        properties.append((key: ReadiumCSSKey.columnCount.rawValue,
                           value: columnCount.name()))

        // WordSpacing count.
        properties.append((key: ReadiumCSSKey.wordSpacing.rawValue,
                           value: wordSpacing.stringValueCss()))
        // LetterSpacing count.
        properties.append((key: ReadiumCSSKey.letterSpacing.rawValue,
                           value: letterSpacing.stringValueCss()))

        // Page margins.
        if let pageMargins = pageMargins {
            properties.append((key: ReadiumCSSKey.pageMargins.rawValue,
                               value: pageMargins.stringValue()))
        }
        return properties
    }

    // Save settings to userDefault.
    public func save() {
        let userDefaults = UserDefaults.standard

        if let fontSize = fontSize {
            userDefaults.set(fontSize, forKey: ReadiumCSSKey.fontSize.rawValue)
        }
        if let font =  font {
            userDefaults.set(font.name(), forKey: ReadiumCSSKey.font.rawValue)
        }
        if let appearance = appearance {
            userDefaults.set(appearance.name(), forKey: ReadiumCSSKey.appearance.rawValue)
        }
        if let scroll = scroll {
            userDefaults.set(scroll.name(), forKey: ReadiumCSSKey.scroll.rawValue)
        }
        userDefaults.set(publisherSettings, forKey: ReadiumCSSKey.publisherSettings.rawValue)

        userDefaults.set(textAlignement.rawValue, forKey: ReadiumCSSKey.textAlignement.rawValue)
        userDefaults.set(columnCount.name(), forKey: ReadiumCSSKey.columnCount.rawValue)
        userDefaults.set(wordSpacing.value, forKey: ReadiumCSSKey.wordSpacing.rawValue)
        userDefaults.set(letterSpacing.value, forKey: ReadiumCSSKey.letterSpacing.rawValue)
        if let pageMargins = pageMargins {
            userDefaults.set(pageMargins.value, forKey: ReadiumCSSKey.pageMargins.rawValue)
        }
    }

    /// Check if a given key is set in the UserDefaults.
    ///
    /// - Parameter key: The key name.
    /// - Returns: A boolean value indicating if the value is present.
    private func isKeyPresentInUserDefaults(key: ReadiumCSSKey) -> Bool {
        return UserDefaults.standard.object(forKey: key.rawValue) != nil
    }
}
