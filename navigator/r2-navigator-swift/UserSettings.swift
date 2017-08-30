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
    // The different key storing the user settings in the UserDefaults.
    public enum Keys: String {
        case fontSize = "--USER__fontSize"
        case appearance = "--USER__appearance"
    }

    // The global fontSize in %.
    internal var fontSize: String?
    // Default, night, sepia.
    public var appearance: Appearances?

    public enum Appearances: String {
        case `default` = "readium-default"
        case sepia = "readium-sepia"
        case night = "readium-night"

        public init(_ value: Int) {
            switch value {
            case 1:
                self = .sepia
            case 2:
                self = .night
            default:
                self = .default
            }
        }

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
    }

    internal init() {
        let userDefaults = UserDefaults.standard

        //load settings from userDefaults.
        if isKeyPresentInUserDefaults(key: Keys.fontSize) {
            fontSize = (userDefaults.string(forKey: Keys.fontSize.rawValue))
        }
        if isKeyPresentInUserDefaults(key: Keys.appearance),
            let value = userDefaults.string(forKey: Keys.appearance.rawValue) {
            appearance = Appearances.init(rawValue: value)
        }
    }

    //
    public func set(value: String, forKey key: Keys) {
        switch key {
        case .fontSize:
            fontSize = value
        case .appearance:
            appearance = Appearances.init(rawValue: value)
        }

    }

    public func getValue(forKey key: Keys) -> String? {
        switch key {
        case .fontSize:
            return fontSize
        case .appearance:
            return appearance?.rawValue
        }
    }

    public func getProperties() -> [(key: String, value: String)] {
        var properties = [(key: String, value: String)]()

        if let fontSize = fontSize {
            properties.append((key: Keys.fontSize.rawValue, "\(fontSize)%"))
        }
        if let appearance = appearance {
            properties.append((key: Keys.appearance.rawValue, "\(appearance.rawValue)"))
        }
        return properties
    }

    // Save settings to userDefault.
    public func save() {
        let userDefaults = UserDefaults.standard

        if let fontSize = fontSize {
            userDefaults.set(fontSize, forKey: Keys.fontSize.rawValue)
        }
        if let appearance = appearance {
            userDefaults.set(appearance.rawValue, forKey: Keys.appearance.rawValue)
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
