//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

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
    var values: JSONDictionary

    /// Creates a `Preferences` object from a JSON object.
    public init(json: [String: Any] = [:]) {
        self.values = JSONDictionary(json) ?? JSONDictionary()
    }

    /// Creates a `Preferences` object from a JSON object.
    public init(jsonString: String) throws {
        guard let json = try? JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as? [String: Any] else {
            throw JSONError.parsing(Preferences.self)
        }
        self.init(json: json)
    }

    /// Returns the JSON representation of this `Preferences`.
    public var json: [String: Any] {
        values.json
    }

    /// Returns the JSON representation of this `Preferences`.
    public var jsonString: String? {
        serializeJSONString(json)
    }

    /// Get the preference for the given `setting`.
    public func get<Value>(_ setting: Setting<Value>) throws -> Value? {
        guard let value = values.json[setting.key.id] else {
            return nil
        }
        return setting.decode(value)
    }

    /// Sets the preference for the given `setting`.
    ///
    /// If `activate` is true, the setting will be force activated if needed.
    public mutating func set<Value>(_ setting: Setting<Value>, preference: Value?, activate: Bool = false) {
        let value = preference.flatMap { setting.validate($0) }

        set(setting.key, preference: value, coder: setting.coder)

        if value != nil && activate {
            self.activate(setting)
        }
    }

    /// Sets the preference for the given setting `key`.
    public mutating func set<Value>(_ key: SettingKey, preference: Value?, coder: SettingCoder<Value>) {
        if let preference = preference {
            values.json[key.id] = coder.encode(preference)
        } else {
            values.json.removeValue(forKey: key.id)
        }
    }

    /// Access the preference for the given `setting`.
    public subscript<Value>(_ setting: Setting<Value>) -> Value? {
        get {
            try? get(setting)
        }
        mutating set(newValue) {
            set(setting, preference: newValue)
        }
    }

    /// Removes the preference for the given `setting`.
    public mutating func remove<Value>(_ setting: Setting<Value>?) {
        guard let setting = setting else {
            return
        }
        values.json.removeValue(forKey: setting.key.id)
    }

    /// Clears all preferences.
    public mutating func clear() {
        values.json.removeAll()
    }

    /// Merges the preferences of `other`, overwriting the ones from the receiver in case of
    /// conflict.
    public mutating func merge(_ other: Preferences) {
        values.json.merge(other.values.json, uniquingKeysWith: { _, n in n })
    }

    /// Creates a copy of this `Preferences` receiver, keeping only the preferences for the given
    /// setting keys.
    public func filter(settings: SettingKey...) -> Self {
        filter(settings: settings)
    }

    /// Creates a copy of this `Preferences` receiver, keeping only the preferences for the given
    /// setting keys.
    public func filter(settings: [SettingKey]) -> Self {
        Preferences(json: values.json.filter { key, _ in settings.contains(where: { $0.id == key }) })
    }

    /// Creates a copy of this `Preferences` receiver, excluding the preferences for the given
    /// setting keys.
    public func filterNot(settings: SettingKey...) -> Self {
        filterNot(settings: settings)
    }

    /// Creates a copy of this `Preferences` receiver, excluding the preferences for the given
    /// setting keys.
    public func filterNot(settings: [SettingKey]) -> Self {
        Preferences(json: values.json.filter { key, _ in !settings.contains(where: { $0.id == key }) })
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

    /// Sets the preference for the given `setting` after transforming the current value.
    ///
    /// If `activate` is true, the setting will be force activated if needed.
    public mutating func update<Value>(_ setting: Setting<Value>, activate: Bool = true, transform: (Value) -> Value) {
        set(setting, preference: transform(prefOrValue(of: setting)), activate: activate)
    }

    /// Toggles the preference for the given `setting`.
    ///
    /// If `activate` is true, the setting will be force activated if needed.
    public mutating func toggle(_ setting: ToggleSetting, activate: Bool = true) {
        set(setting, preference: !prefOrValue(of: setting), activate: activate)
    }

    /// Toggles the preference for the enum `setting` to the given `preference`.
    ///
    /// If the preference was already set to the same value, it is removed.
    /// If `activate` is true, the setting will be force activated if needed.
    public mutating func toggle<Value: Equatable>(_ setting: Setting<Value>, preference: Value, activate: Bool = true) {
        let current = try? get(setting)
        if current == nil || current! != preference {
            set(setting, preference: preference, activate: activate)
        } else {
            remove(setting)
        }
    }

    /// Increments the preference for the given `setting` to the next step.
    ///
    /// If the `setting` doesn't have any suggested steps, the `next` function will be used instead
    /// to determine the next step.
    ///
    /// If `activate` is true, the setting will be force activated if needed.
    public mutating func increment<Value>(_ setting: RangeSetting<Value>, activate: Bool = true, next: (Value) -> Value) {
        if let steps = setting.suggestedSteps {
            guard
                let index = steps.lastIndex(where: { $0 <= prefOrValue(of: setting) }),
                let nextValue = steps.getOrNil(index + 1)
            else {
                return
            }
            set(setting, preference: nextValue, activate: activate)

        } else {
            update(setting, activate: activate, transform: next)
        }
    }

    /// Decrements the preference for the given `setting` to the previous step.
    ///
    /// If the `setting` doesn't have any suggested steps, the `previous` function will be used
    /// instead to determine the previous step.
    ///
    /// If `activate` is true, the setting will be force activated if needed.
    public mutating func decrement<Value>(_ setting: RangeSetting<Value>, activate: Bool = true, previous: (Value) -> Value) {
        if let steps = setting.suggestedSteps {
            guard
                let index = steps.lastIndex(where: { $0 >= prefOrValue(of: setting) }),
                let nextValue = steps.getOrNil(index - 1)
            else {
                return
            }
            set(setting, preference: nextValue, activate: activate)

        } else {
            update(setting, activate: activate, transform: previous)
        }
    }

    /// Increments the preference for the given `setting` to the next step.
    ///
    /// The setting is incremented by the given `amount`, if it doesn't have any suggested steps or
    /// increment.
    ///
    /// If `activate` is true, the setting will be force activated if needed.
    public mutating func increment<Value: SignedInteger>(_ setting: RangeSetting<Value>, amount: Value? = nil, activate: Bool = true) {
        let amount = amount ?? setting.suggestedIncrement ?? 1
        increment(setting, activate: activate, next: { $0 + amount })
    }

    /// Decrements the preference for the given `setting` to the previous step.
    ///
    /// The setting is decremented by the given `amount`, if it doesn't have any suggested steps or
    /// increment.
    ///
    /// If `activate` is true, the setting will be force activated if needed.
    public mutating func decrement<Value: SignedInteger>(_ setting: RangeSetting<Value>, amount: Value? = nil, activate: Bool = true) {
        let amount = amount ?? setting.suggestedIncrement ?? 1
        increment(setting, activate: activate, next: { $0 - amount })
    }

    /// Increments the preference for the given `setting` to the next step.
    ///
    /// The setting is decremented by the given `amount`, if it doesn't have any suggested steps or
    /// increment.
    ///
    /// If `activate` is true, the setting will be force activated if needed.
    public mutating func increment(_ setting: RangeSetting<Double>, amount: Double? = nil, activate: Bool = true) {
        let amount = amount ?? setting.suggestedIncrement ?? 0.1
        increment(setting, activate: activate, next: { $0 + amount })
    }

    /// Decrements the preference for the given `setting` to the previous step.
    ///
    /// The setting is decremented by the given `amount`, if it doesn't have any suggested steps or
    /// increment.
    ///
    /// If `activate` is true, the setting will be force activated if needed.
    public mutating func decrement(_ setting: RangeSetting<Double>, amount: Double? = nil, activate: Bool = true) {
        let amount = amount ?? setting.suggestedIncrement ?? 0.1
        increment(setting, activate: activate, next: { $0 - amount })
    }

    /// Adjusts the preference for the given `setting` by adding `amount`.
    ///
    /// If `activate` is true, the setting will be force activated if needed.
    public mutating func adjustBy<Value: Numeric>(_ setting: RangeSetting<Value>, amount: Value, activate: Bool = true) {
        update(setting, activate: activate) { $0 + amount }
    }

    /// Returns the preference for the given `Setting`, or its current value when missing.
    private func prefOrValue<Value>(of setting: Setting<Value>) -> Value {
        (try? get(setting)) ?? setting.value
    }
}

extension Preferences: CustomStringConvertible {
    public var description: String {
        "Preferences(\(json))"
    }
}