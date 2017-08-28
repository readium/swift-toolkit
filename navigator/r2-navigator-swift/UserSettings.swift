//
//  UserSettings.swift
//  r2-navigator-swift
//
//  Created by Alexandre Camilleri on 8/25/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

public class UserSettings {
    // The different key storing the user settings in the UserDefaults.
    public enum Keys: String {
        case fontSize = "--USER__fontSize"
        case appearance = "--USER__appearance"
    }

    // The global fontSize in %.
    internal var fontSize: String?
    // Default, night, sepia.
    internal var appearance: String?

    public enum Appearances: String {
        case `default` = "readium-default"
        case sepia = "readium-sepia"
        case night = "readium-night"
    }

    internal init() {
        let userDefaults = UserDefaults.standard

        //load settings from userDefaults.
        if isKeyPresentInUserDefaults(key: Keys.fontSize) {
            fontSize = (userDefaults.string(forKey: Keys.fontSize.rawValue))
        }
        if isKeyPresentInUserDefaults(key: Keys.appearance) {
            appearance = (userDefaults.string(forKey: Keys.appearance.rawValue))
        }
    }

    //
    public func set(value: String, forKey key: Keys) {
        switch key {
        case .fontSize:
            fontSize = value
        case .appearance:
            appearance = value
        }

    }

    public func getValue(forKey key: Keys) -> String? {
        switch key {
        case .fontSize:
            return fontSize
        case .appearance:
            return appearance
        }
    }

    public func getProperties() -> [(key: String, value: String)] {
        var properties = [(key: String, value: String)]()

        if let fontSize = fontSize {
            properties.append((key: Keys.fontSize.rawValue, "\(fontSize)%"))
        }
        if let appearance = appearance {
            properties.append((key: Keys.appearance.rawValue, "\(appearance)"))
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
            userDefaults.set(appearance, forKey: Keys.appearance.rawValue)
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
