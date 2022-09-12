//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Set of preferences used to update a `Configurable`'s settings.
///
/// `Preferences` can be serialized to JSON, which is useful to persist user preferences.
///
/// Usage example:
///
///     // Get the currently available settings for the configurable.
///     let settings = configurable.settings.value
///
///     // Build a new set of Preferences, using the Setting objects as keys.
///     var prefs = Preferences()
///     prefs.set(settings.scroll, false)
///     prefs.increment(settings.fontSize)
///
///     // Apply the preferences to the Configurable, which will automatically update its settings
///     // accordingly.
///     configurable.applyPreferences(prefs)
public struct Preferences: Hashable, Loggable {
    var values: [String: AnyHashable]

    /// Creates a `Preferences` object from a JSON object.
    public init(json: [String: Any] = [:]) {
        self.values = json
    }

    /// Creates a copy of this `Preferences` receiver, keeping only the preferences for the given
    /// setting keys.
    public func filter(settings: SettingKey...) -> Self {
        filter(settings: settings)
    }

    /// Creates a copy of this `Preferences` receiver, keeping only the preferences for the given
    /// setting keys.
    public func filter(settings: [SettingKey]) -> Self {
        Preferences(json: values.filter { key, _ in settings.contains(where: { $0.id == key }) })
    }

    /// Creates a copy of this `Preferences` receiver, excluding the preferences for the given
    /// setting keys.
    public func filterNot(settings: SettingKey...) -> Self {
        filterNot(settings: settings)
    }

    /// Creates a copy of this `Preferences` receiver, excluding the preferences for the given
    /// setting keys.
    public func filterNot(settings: [SettingKey]) -> Self {
        Preferences(json: values.filter { key, _ in !settings.contains(where: { $0.id == key }) })
    }

    /// Get the preference for the given `setting`.
    public func get<Value>(_ setting: Setting<Value>) throws -> Value? {
        guard let value = values[setting.key] else {
            return nil
        }
        return try JSONDecoder().decode(Value.self, from: value)
    }

    /// Sets the preference for the given `setting`.
    ///
    /// - Parameter activate: Indicates whether the setting will be force activated if needed.
    public mutating func set<Value>(_ setting: Setting<Value>, preference: Value?, activate: Bool = false) throws {
        let value = preference.flatMap { setting.validate(it) }

        set(setting.key, preference: value)

        if value != nil && activate {
            activate(setting)
        }
    }

    /// Sets the preference for the given setting `key`.
    public mutating func set<Value: Codable>(_ key: SettingKey, preference: Value?) throws {
        if let preference = preference {
            values[key.id] = try JSONEncoder().encode(preference)
        } else {
            values.removeValue(forKey: key.id)
        }
    }

    /// Access the preference for the given `setting`.
    public subscript<Value>(_ setting: Setting<Value>) -> Value? {
        get {
            try? get(setting)
        }
        mutating set(newValue) {
            try? set(setting, preference: newValue)
        }
    }

    /// Removes the preference for the given `setting`.
    public func remove<Value>(_ setting: Setting<Value>?) {
        guard let setting = setting else {
            return
        }
        values.removeValue(forKey: setting.key)
    }

    /// Clears all preferences.
    public func clear() {
        values.removeAll()
    }

    /// Merges the preferences of `other`, overwriting the ones from the receiver in case of
    /// conflict.
    public func merge(_ other: Preferences) {
        values.merge(other.values, uniquingKeysWith: { _, n in n })
    }

    /// Returns whether the given `setting` is active in these preferences.
    ///
    /// An inactive setting is ignored by the `Configurable` until its activation conditions are met
    /// (e.g. another setting has a certain preference).
    public func isActive<Value>(_ setting: Setting<Value>) -> Bool {
        setting.isActive(with: self)
    }

    /// Activates the given `setting` in the preferences, if needed.
    public mutating func activate<Value>(_ setting: Setting<Value>) {
        guard !isActive(setting) else {
            return
        }
        setting.activate(in: &self)
    }
}