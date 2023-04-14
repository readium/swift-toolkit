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

    struct State {
        var preferences: Preferences
        var settings: Settings
    }

    private var state: State
    private let makeSettings: (Preferences) -> Settings

    init(initialPreferences: Preferences, settings: @escaping (Preferences) -> Settings) {
        self.makeSettings = settings
        self.state = State(
            preferences: initialPreferences,
            settings: settings(initialPreferences)
        )
    }

    public var preferences: Preferences { state.preferences }

    public func clear() {
        edit { $0 = .empty }
    }

    private func edit(with changes: (inout Preferences) -> Void) {
        precondition(Thread.isMainThread)
        var state = state
        changes(&state.preferences)
        state.settings = makeSettings(state.preferences)
        self.state = state
    }

    func preference<Value>(
        preference prefKP: WritableKeyPath<Preferences, Value?>,
        setting settingKP: KeyPath<Settings, Value>,
        isEffective: @escaping (State) -> Bool
    ) -> AnyPreference<Value> {
        preference(
            preference: prefKP,
            effectiveValue: { $0.settings[keyPath: settingKP] },
            isEffective: isEffective
        )
    }

    func preference<Value>(
        preference prefKP: WritableKeyPath<Preferences, Value?>,
        effectiveValue: @escaping (State) -> Value,
        isEffective: @escaping (State) -> Bool
    ) -> AnyPreference<Value> {
        ProxyPreference(
            value: { [unowned self] in preferences[keyPath: prefKP] },
            effectiveValue: { [unowned self] in effectiveValue(state) },
            isEffective: { [unowned self] in isEffective(state) },
            set: { [unowned self] v in edit { $0[keyPath: prefKP] = v } }
        ).eraseToAnyPreference()
    }

    func preference<Value>(
        preference prefKP: WritableKeyPath<Preferences, Value?>,
        setting settingKP: KeyPath<Settings, Value?>,
        isEffective: @escaping (State) -> Bool
    ) -> AnyPreference<Value?> {
        ProxyPreference(
            value: { [unowned self] in preferences[keyPath: prefKP] },
            effectiveValue: { [unowned self] in state.settings[keyPath: settingKP] },
            isEffective: { [unowned self] in isEffective(state) },
            set: { [unowned self] v in edit { $0[keyPath: prefKP] = v ?? nil } }
        ).eraseToAnyPreference()
    }

    func enumPreference<Value>(
        preference prefKP: WritableKeyPath<Preferences, Value?>,
        setting settingKP: KeyPath<Settings, Value>,
        isEffective: @escaping (State) -> Bool,
        supportedValues: [Value]
    ) -> AnyEnumPreference<Value> {
        enumPreference(
            preference: prefKP,
            effectiveValue: { $0.settings[keyPath: settingKP] },
            isEffective: isEffective,
            supportedValues: supportedValues
        )
    }

    func enumPreference<Value>(
        preference prefKP: WritableKeyPath<Preferences, Value?>,
        effectiveValue: @escaping (State) -> Value,
        isEffective: @escaping (State) -> Bool,
        supportedValues: [Value]
    ) -> AnyEnumPreference<Value> {
        ProxyEnumPreference(
            value: { [unowned self] in preferences[keyPath: prefKP] },
            effectiveValue: { [unowned self] in effectiveValue(state) },
            isEffective: { [unowned self] in isEffective(state) },
            set: { [unowned self] v in edit { $0[keyPath: prefKP] = v } },
            supportedValues: supportedValues
        ).eraseToAnyPreference()
    }

    func enumPreference<Value>(
        preference prefKP: WritableKeyPath<Preferences, Value?>,
        setting settingKP: KeyPath<Settings, Value?>,
        isEffective: @escaping (State) -> Bool,
        supportedValues: [Value?]
    ) -> AnyEnumPreference<Value?> {
        ProxyEnumPreference(
            value: { [unowned self] in preferences[keyPath: prefKP] },
            effectiveValue: { [unowned self] in state.settings[keyPath: settingKP] },
            isEffective: { [unowned self] in isEffective(state) },
            set: { [unowned self] v in edit { $0[keyPath: prefKP] = v ?? nil } },
            supportedValues: supportedValues
        ).eraseToAnyPreference()
    }

    func rangePreference<Value: Comparable>(
        preference prefKP: WritableKeyPath<Preferences, Value?>,
        setting settingKP: KeyPath<Settings, Value>,
        isEffective: @escaping (State) -> Bool,
        supportedRange: ClosedRange<Value>,
        progressionStrategy: AnyProgressionStrategy<Value>,
        format: @escaping (Value) -> String
    ) -> AnyRangePreference<Value> {
       rangePreference(
            preference: prefKP,
            effectiveValue: { $0.settings[keyPath: settingKP] },
            isEffective: isEffective,
            supportedRange: supportedRange,
            progressionStrategy: progressionStrategy,
            format: format
        )
    }

    func rangePreference<Value: Comparable>(
        preference prefKP: WritableKeyPath<Preferences, Value?>,
        effectiveValue: @escaping (State) -> Value,
        isEffective: @escaping (State) -> Bool,
        supportedRange: ClosedRange<Value>,
        progressionStrategy: AnyProgressionStrategy<Value>,
        format: @escaping (Value) -> String
    ) -> AnyRangePreference<Value> {
        ProxyRangePreference(
            value: { [unowned self] in preferences[keyPath: prefKP] },
            effectiveValue: { [unowned self] in effectiveValue(state) },
            isEffective: { [unowned self] in isEffective(state) },
            set: { [unowned self] v in edit { $0[keyPath: prefKP] = v } },
            supportedRange: supportedRange,
            progressionStrategy: progressionStrategy,
            format: format
        ).eraseToAnyPreference()
    }
}
