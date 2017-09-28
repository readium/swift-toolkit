//
//  UserSettings.swift
//  r2-navigator-swift
//
//  Created by Alexandre Camilleri on 8/25/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import UIKit

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

    // The keys in ReadiumCss. Also used for storing UserSettings in UserDefaults.
    public enum Keys: String {
        case fontSize = "--USER__fontSize"
        case font = "--USER__fontFamily"
        case appearance = "--USER__appearance"
        case scroll = "--USER__scroll"
        case publisherSettings = "--USER__advancedSettings"
        case wordSpacing = "--USER__wordSpacing"
        case letterSpacing = "--USER__letterSpacing"
        case columnCount = "--USER__colCount"
        case pageMargins = "--USER__pageMargins"
        case textAlignement = "--USER__textAlign"
        //--USER__darkenImages --USER__invertImages
    }

    internal enum Switches: String {
        case publisherFont = "--USER__fontOverride"
    }

    internal init() {
        let userDefaults = UserDefaults.standard
        var value: String

        /// Load settings from userDefaults.
        // Font size.
        if isKeyPresentInUserDefaults(key: Keys.fontSize) {
            fontSize = userDefaults.string(forKey: Keys.fontSize.rawValue)
        } else {
            fontSize = "100"
        }

        // Font type.
        value = userDefaults.string(forKey: Keys.font.rawValue) ?? ""
        font = Font.init(with: value)

        // Appearance.
        if isKeyPresentInUserDefaults(key: Keys.appearance),
            let value = userDefaults.string(forKey: Keys.appearance.rawValue) {
            appearance = Appearance.init(with: value)
        }

        // Scroll mod.
        value = userDefaults.string(forKey: Keys.scroll.rawValue) ?? ""
        scroll = Scroll.init(with: value)

        // Publisher settings.
        publisherSettings = userDefaults.bool(forKey: Keys.publisherSettings.rawValue)

        // Page Margins. (0 if unset in the userDefaults)
        let pageMarginsValue = userDefaults.double(forKey: Keys.pageMargins.rawValue)

        self.pageMargins = PageMargins.init(initialValue: pageMarginsValue)

        // Text alignement.
        let textAlignement = userDefaults.integer(forKey: Keys.textAlignement.rawValue)
        self.textAlignement = TextAlignement.init(with: textAlignement)
        // Word spacing.
        let wordSpacingValue = userDefaults.double(forKey: Keys.wordSpacing.rawValue)
        wordSpacing = WordSpacing.init(initialValue: wordSpacingValue)

        // Letter spacing.
        let letterSpacingValue = userDefaults.double(forKey: Keys.letterSpacing.rawValue)
        letterSpacing = LetterSpacing.init(initialValue: letterSpacingValue)

        // Column count.
        value = userDefaults.string(forKey: Keys.columnCount.rawValue) ?? ""
        columnCount = ColumnCount.init(with: value)
    }

    public func value(forKey key: Keys) -> String? {
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
            properties.append((key: Keys.fontSize.rawValue, "\(fontSize)%"))
        }

        // Font.
        if let font = font {
            // Do we override?
            let value = (font == .publisher ? "readium-font-off" : "readium-font-on")

            properties.append((key: Switches.publisherFont.rawValue, value))
            properties.append((key: Keys.font.rawValue, "\(font.name(css: true))"))
        }
        // Appearance.
        if let appearance = appearance {
            properties.append((key: Keys.appearance.rawValue, "\(appearance.name())"))
        }
        // Scroll.
        if let scroll = scroll {
            properties.append((key: Keys.scroll.rawValue, value: "\(scroll.name())"))
        }
        // Publisher Settings.
        value = (publisherSettings == true ? "readium-advanced-off" : "readium-advanced-on")
        properties.append((key: Keys.publisherSettings.rawValue, value: "\(value)"))

        /// Advanced Settings.
        // Text alignement.
        properties.append((key: Keys.textAlignement.rawValue,
                           value: textAlignement.stringValueCss()))

        // Column count.
        properties.append((key: Keys.columnCount.rawValue,
                           value: columnCount.name()))

        // WordSpacing count.
        properties.append((key: Keys.wordSpacing.rawValue,
                           value: wordSpacing.stringValueCss()))
        // LetterSpacing count.
        properties.append((key: Keys.letterSpacing.rawValue,
                           value: letterSpacing.stringValueCss()))

        // Page margins.
        if let pageMargins = pageMargins {
            properties.append((key: Keys.pageMargins.rawValue,
                               value: pageMargins.stringValue()))
        }
        return properties
    }

    // Save settings to userDefault.
    public func save() {
        let userDefaults = UserDefaults.standard

        if let fontSize = fontSize {
            userDefaults.set(fontSize, forKey: Keys.fontSize.rawValue)
        }
        if let font =  font {
            userDefaults.set(font.name(), forKey: Keys.font.rawValue)
        }
        if let appearance = appearance {
            userDefaults.set(appearance.name(), forKey: Keys.appearance.rawValue)
        }
        if let scroll = scroll {
            userDefaults.set(scroll.name(), forKey: Keys.scroll.rawValue)
        }
        userDefaults.set(publisherSettings, forKey: Keys.publisherSettings.rawValue)

        userDefaults.set(textAlignement.rawValue, forKey: Keys.textAlignement.rawValue)
        userDefaults.set(columnCount.name(), forKey: Keys.columnCount.rawValue)
        userDefaults.set(wordSpacing.value, forKey: Keys.wordSpacing.rawValue)
        userDefaults.set(letterSpacing.value, forKey: Keys.letterSpacing.rawValue)
        if let pageMargins = pageMargins {
            userDefaults.set(pageMargins.value, forKey: Keys.pageMargins.rawValue)
        }
    }

    /// Check if a given key is set in the UserDefaults.
    ///
    /// - Parameter key: The key name.
    /// - Returns: A boolean value indicating if the value is present.
    private func isKeyPresentInUserDefaults(key: Keys) -> Bool {
        return UserDefaults.standard.object(forKey: key.rawValue) != nil
    }
}
