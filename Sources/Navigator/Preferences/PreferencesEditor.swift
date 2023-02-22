//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Interactive editor of preferences.
///
/// This can be used as a helper for a user preferences screen.
public protocol PreferencesEditor: AnyObject {
    associatedtype Preferences: ConfigurablePreferences

    /// The current preferences.
    var preferences: Preferences { get }

    /// Unset all preferences.
    func clear()
}

/// This base class can be used to build a mutable `PreferencesEditor` with
/// a more declarative API.
public class StatefulPreferencesEditor<Preferences: ConfigurablePreferences, Settings: ConfigurableSettings> : PreferencesEditor {

    private let initialPreferences: Preferences
    private let emptyPreferences: Preferences
    private let makeSettings: (Preferences) -> Settings

    init(initialPreferences: Preferences, emptyPreferences: Preferences, makeSettings: @escaping (Preferences) -> Settings) {
        self.initialPreferences = initialPreferences
        self.emptyPreferences = emptyPreferences
        self.makeSettings = makeSettings
        self.state = makeState(from: initialPreferences)
    }

    public var preferences: Preferences {
        state.preferences
    }

    public func clear() {
        edit { $0 = emptyPreferences }
    }

    private func edit(with changes: (inout Preferences) -> Void) {
        var prefs = preferences
        changes(&prefs)
        state = makeState(from: prefs)
    }

    private struct State {
        var preferences: Preferences
        var settings: Settings
    }

    private var state: State!

    private func makeState(from preferences: Preferences) -> State {
        State(
            preferences: preferences,
            settings: makeSettings(preferences)
        )
    }

    func preference<Value>(
        preference prefKP: WritableKeyPath<Preferences, Value?>,
        setting settingKP: KeyPath<Settings, Value>,
        isEffective: @escaping (Settings) -> Bool
    ) -> AnyPreference<Value> {
        ProxyPreference(
            value: { [unowned self] in preferences[keyPath: prefKP] },
            effectiveValue: { [unowned self] in state.settings[keyPath: settingKP] },
            isEffective: { [unowned self] in isEffective(state.settings) },
            set: { [unowned self] v in edit { $0[keyPath: prefKP] = v } }
        ).eraseToAnyPreference()
    }

    func enumPreference<Value>(
        preference prefKP: WritableKeyPath<Preferences, Value?>,
        setting settingKP: KeyPath<Settings, Value>,
        isEffective: @escaping (Settings) -> Bool,
        supportedValues: [Value]
    ) -> AnyEnumPreference<Value> {
        ProxyEnumPreference(
            value: { [unowned self] in preferences[keyPath: prefKP] },
            effectiveValue: { [unowned self] in state.settings[keyPath: settingKP] },
            isEffective: { [unowned self] in isEffective(state.settings) },
            set: { [unowned self] v in edit { $0[keyPath: prefKP] = v } },
            supportedValues: supportedValues
        ).eraseToAnyPreference()
    }

    func rangePreference<Value: Comparable>(
        preference prefKP: WritableKeyPath<Preferences, Value?>,
        setting settingKP: KeyPath<Settings, Value>,
        isEffective: @escaping (Settings) -> Bool,
        format: @escaping (Value) -> String,
        supportedRange: ClosedRange<Value>,
        progressionStrategy: AnyProgressionStrategy<Value>
    ) -> AnyRangePreference<Value> {
        ProxyRangePreference(
            value: { [unowned self] in preferences[keyPath: prefKP] },
            effectiveValue: { [unowned self] in state.settings[keyPath: settingKP] },
            isEffective: { [unowned self] in isEffective(state.settings) },
            set: { [unowned self] v in edit { $0[keyPath: prefKP] = v } },
            format: format,
            supportedRange: supportedRange,
            progressionStrategy: progressionStrategy
        ).eraseToAnyPreference()
    }
}
