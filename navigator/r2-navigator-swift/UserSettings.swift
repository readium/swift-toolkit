//
//  UserSettings.swift
//  r2-navigator-swift
//
//  Created by Alexandre Camilleri on 8/25/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import UIKit

let pageMarginsDefault = 1.0

public class UserSettings {
    // FontSize in %.
    public var fontSize: String?
    public var font: Font?
    public var appearance: Appearance?
    public var scroll: Scroll?
    public var publisherSettings: Bool!
    public var wordSpacing: WordSpacing!
    public var letterSpacing: LetterSpacing!
    public var columnCount: ColumnCount!
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
        //--USER__darkenImages --USER__invertImages
    }

    internal enum Switches: String {
        case publisherFont = "--USER__fontOverride"
    }

    /// Font available in userSettings.
    public enum Font: Int {
        case publisher
        case sans
        case oldStyle
        case modern
        case humanist

        public static let allValues = [publisher, sans, oldStyle, modern, humanist]

        public init(with name: String) {
            switch name {
            case Font.sans.name():
                self = .sans
            case Font.oldStyle.name():
                self = .oldStyle
            case Font.modern.name():
                self = .modern
            case Font.humanist.name():
                self = .humanist
            default:
                self = .publisher
            }
        }

        /// Return the associated font name, or the CSS version.
        ///
        /// - Parameter css: If true, return the precise CSS full name.
        /// - Returns: The font name.
        public func name(css: Bool = false) -> String {
            switch self {
            case .publisher:
                return "Publisher's default"
            case .sans:
                return "Helvetica Neue"
            case .oldStyle:
                return (css ? "Iowan Old Style" : "Iowan")
            case .modern:
                return "Athelas"
            case .humanist:
                return "Seravek"
            }
        }
    }

    /// Appearances available in UserSettings.
    public enum Appearance: Int {
        case `default`
        case sepia
        case night

        public init(with name: String) {
            switch name {
            case Appearance.sepia.name():
                self = .sepia
            case Appearance.night.name():
                self = .night
            default:
                self = .default
            }
        }

        /// The associated name for ReadiumCss.
        ///
        /// - Returns: Appearance name.
        public func name() -> String{
            switch self {
            case .default:
                return "readium-default-on"
            case .sepia:
                return "readium-sepia-on"
            case .night:
                return "readium-night-on"
            }
        }

        /// The associated color for the UI.
        ///
        /// - Returns: Color.
        public func associatedColor() -> UIColor {
            switch self {
            case .default:
                return UIColor.white
            case .sepia:
                return UIColor.init(red: 250/255, green: 244/255, blue: 232/255, alpha: 1)
            case .night:
                return UIColor.black

            }
        }

        /// The associated color for the fonts.
        ///
        /// - Returns: Color.
        public func associatedFontColor() -> UIColor {
            switch self {
            case .default:
                return UIColor.black
            case .sepia:
                return UIColor.init(red: 18/255, green: 18/255, blue: 18/255, alpha: 1)
            case .night:
                return UIColor.init(red: 254/255, green: 254/255, blue: 254/255, alpha: 1)

            }
        }
    }

    public enum Scroll {
        case on
        case off

        public init(with name: String) {
            switch name {
            case Scroll.on.name():
                self = .on
            default:
                self = .off
            }
        }

        public func name() -> String {
            switch self {
            case .on:
                return "readium-scroll-on"
            case .off:
                return "readium-scroll-off"
            }
        }

        public func bool() -> Bool {
            switch self {
            case .on:
                return true
            default:
                return false
            }
        }
    }

    public enum ColumnCount: Int {
        case auto
        case one
        case two

        init(with name: String) {
            switch name {
            case ColumnCount.one.name():
                self = .one
            case ColumnCount.two.name():
                self = .two
            default:
                self = .auto
            }
        }

        public func name() -> String {
            switch self {
            case .auto:
                return "auto"
            case .one:
                return "1"
            case .two:
                return "2"
            }
        }
    }

    public class PageMargins {
        public let step = 0.25
        public let min = 0.5
        public let max = 2.0
        public var value: Double!

        public init(initialValue: Double) {
            if initialValue < min || initialValue > max,
                (initialValue.truncatingRemainder(dividingBy: step) != 0)
            {
                value = 1
            }
            value = initialValue
        }

        public func increment() {
            guard value + step <= max else {
                return
            }
            value = value + step
        }

        public func decrement() {
            guard value - step >= min else {
                return
            }
            value = value - step
        }

        public func stringValue() -> String {
            return "\(value!)"
        }
    }

    public enum WordSpacing: Int {
        case auto
        case one
        case two
        case three
        case four

        init(with name: String) {
            switch name {
            case WordSpacing.one.name():
                self = .one
            case WordSpacing.two.name():
                self = .two
            case WordSpacing.three.name():
                self = .three
            case WordSpacing.four.name():
                self = .four
            default:
                self = .auto
            }
        }

        public func name() -> String {
            switch self {
            case .auto:
                return "auto"
            case .one:
                return "0.125rem"
            case .two:
                return "0.25rem"
            case .three:
                return "0.375rem"
            case .four:
                return "0.5rem"
            }
        }
    }

    public enum LetterSpacing: Int {
        case auto
        case one
        case two
        case three
        case four

        init(with name: String) {
            switch name {
            case LetterSpacing.one.name():
                self = .one
            case LetterSpacing.two.name():
                self = .two
            case LetterSpacing.three.name():
                self = .three
            case LetterSpacing.four.name():
                self = .four
            default:
                self = .auto
            }
        }

        public func name() -> String {
            switch self {
            case .auto:
                return "auto"
            case .one:
                return "0.0675rem"
            case .two:
                return "0.125rem"
            case .three:
                return "0.1875rem"
            case .four:
                return "0.25rem"
            }
        }
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

        // Word spacing.
        value = userDefaults.string(forKey: Keys.wordSpacing.rawValue) ?? ""
        wordSpacing = WordSpacing.init(with: value)

        // Letter spacing.
        value = userDefaults.string(forKey: Keys.letterSpacing.rawValue) ?? ""
        letterSpacing = LetterSpacing.init(with: value)

        // Column count.
        value = userDefaults.string(forKey: Keys.columnCount.rawValue) ?? ""
        columnCount = ColumnCount.init(with: value)

        // Page Margins. (0 if unset in the userDefaults)
        let pageMarginsValue = userDefaults.double(forKey: Keys.pageMargins.rawValue)

        self.pageMargins = PageMargins.init(initialValue: pageMarginsValue)
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
        case .wordSpacing:
            return wordSpacing.name()
        case .letterSpacing:
            return letterSpacing.name()
        case .columnCount:
            return columnCount?.name()
        case .pageMargins:
            return pageMargins.stringValue()

        }
    }

    /// Generate an array of tuple for setting easily the css properties.
    ///
    /// - Returns: Css properties (key, value).
    public func cssProperties() -> [(key: String, value: String)] {
        var properties = [(key: String, value: String)]()
        var value: String

        if let fontSize = fontSize {
            properties.append((key: Keys.fontSize.rawValue, "\(fontSize)%"))
        }
        if let font = font {
            // Do we override?
            let value = (font == .publisher ? "readium-font-off" : "readium-font-on")
            properties.append((key: Switches.publisherFont.rawValue, value))
            properties.append((key: Keys.font.rawValue, "\(font.name(css: true))"))
        }
        if let appearance = appearance {
            properties.append((key: Keys.appearance.rawValue, "\(appearance.name())"))
        }
        if let scroll = scroll {
            properties.append((key: Keys.scroll.rawValue, value: "\(scroll.name())"))
        }

        // Publisher Settings.
        value = (publisherSettings == true ? "readium-advanced-off" : "readium-advanced-on")
        properties.append((key: Keys.publisherSettings.rawValue, value: "\(value)"))

        // WordSpacing count.
        value = wordSpacing.name()
        properties.append((key: Keys.wordSpacing.rawValue, value: "\(value)"))

        // LetterSpacing count.
        value = letterSpacing.name()
        properties.append((key: Keys.letterSpacing.rawValue, value: "\(value)"))

        // Column count.
        value = columnCount.name()
        properties.append((key: Keys.columnCount.rawValue, value: "\(value)"))

        // Page margins.
        if let pageMargins = pageMargins {
            properties.append((key: Keys.pageMargins.rawValue, value: "\(pageMargins.stringValue())"))
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

        userDefaults.set(wordSpacing.name(), forKey: Keys.wordSpacing.rawValue)
        userDefaults.set(letterSpacing.name(), forKey: Keys.letterSpacing.rawValue)
        userDefaults.set(columnCount.name(), forKey: Keys.columnCount.rawValue)
        if let pageMargins = pageMargins {
            userDefaults.set(pageMargins.stringValue(), forKey: Keys.pageMargins.rawValue)
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
