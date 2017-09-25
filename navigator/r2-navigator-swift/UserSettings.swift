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

    // The keys in ReadiumCss. Also used for storing UserSettings in UserDefaults.
    public enum Keys: String {
        case fontSize = "--USER__fontSize"
        case font = "--USER__fontFamily"
        case appearance = "--USER__appearance"
        case scroll = "--USER__scroll"
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
                return "readium-default"
            case .sepia:
                return "readium-sepia"
            case .night:
                return "readium-night"
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

    internal init() {
        let userDefaults = UserDefaults.standard

        //load settings from userDefaults.
        if isKeyPresentInUserDefaults(key: Keys.fontSize) {
            fontSize = userDefaults.string(forKey: Keys.fontSize.rawValue)
        } else {
            fontSize = "100"
        }
        if isKeyPresentInUserDefaults(key: Keys.font),
            let value = userDefaults.string(forKey: Keys.font.rawValue) {
            font = Font.init(with: value)
        } else {
            font = Font.sans
        }
        if isKeyPresentInUserDefaults(key: Keys.appearance),
            let value = userDefaults.string(forKey: Keys.appearance.rawValue) {
            appearance = Appearance.init(with: value)
        }
        if isKeyPresentInUserDefaults(key: Keys.scroll),
            let value = userDefaults.string(forKey: Keys.scroll.rawValue) {

            scroll = Scroll.init(with: value)
        } else {
            scroll = Scroll.off
        }
    }

    public func set(value: String, forKey key: Keys) {
        switch key {
        case .fontSize:
            fontSize = value
        case .font:
            font = Font.init(with: value)
        case .appearance:
            appearance = Appearance.init(with: value)
        case .scroll:
            scroll = Scroll.init(with: value)
        }

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
        }
    }

    /// Generate an array of tuple for setting easily the css properties.
    ///
    /// - Returns: Css properties (key, value).
    public func cssProperties() -> [(key: String, value: String)] {
        var properties = [(key: String, value: String)]()

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
    }

    /// Check if a given key is set in the UserDefaults.
    ///
    /// - Parameter key: The key name.
    /// - Returns: A boolean value indicating if the value is present.
    private func isKeyPresentInUserDefaults(key: Keys) -> Bool {
        return UserDefaults.standard.object(forKey: key.rawValue) != nil
    }
}
