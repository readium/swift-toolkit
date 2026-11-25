//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumNavigator
import Testing

@MainActor struct OptionalRangePreferenceTests {
    @Test("value is nil when unset, not .some(nil)")
    func valueIsNilWhenUnset() {
        let editor = TestEditor()
        #expect(editor.limit.value == nil)
        #expect(editor.limit.effectiveValue == nil)
    }

    @Test("effective value falls back to the defaults")
    func effectiveValueFallsBackToDefaults() {
        let editor = TestEditor(defaultLimit: 1.5)
        #expect(editor.limit.value == nil)
        #expect(editor.limit.effectiveValue == 1.5)
    }

    @Test("setting a value updates the preferences")
    func setValue() {
        let editor = TestEditor(defaultLimit: 1.5)
        editor.limit.set(0.75)
        #expect(editor.limit.value == 0.75)
        #expect(editor.limit.effectiveValue == 0.75)
        #expect(editor.preferences.limit == 0.75)
    }

    @Test("setting nil unsets the preference", arguments: [nil, .some(nil)] as [Double??])
    func setNil(value: Double??) {
        let editor = TestEditor(preferences: TestPreferences(limit: 1.5))
        editor.limit.set(value)
        #expect(editor.limit.value == nil)
        #expect(editor.preferences.limit == nil)
    }

    @Test("clear unsets the preference")
    func clear() {
        let editor = TestEditor(preferences: TestPreferences(limit: 1.5))
        editor.limit.clear()
        #expect(editor.preferences.limit == nil)
    }

    @Test("values are clamped to the supported range", arguments: [
        (5.0, 2.0),
        (0.1, 0.5),
        (1.25, 1.25),
    ])
    func clampValues(value: Double, expected: Double) {
        let editor = TestEditor()
        editor.limit.set(value)
        #expect(editor.preferences.limit == expected)
    }

    @Test("increment and decrement start from the value")
    func progressFromValue() {
        let editor = TestEditor(preferences: TestPreferences(limit: 1.5), defaultLimit: 0.5)
        editor.limit.increment()
        #expect(editor.preferences.limit == 1.75)
        editor.limit.decrement()
        editor.limit.decrement()
        #expect(editor.preferences.limit == 1.25)
    }

    @Test("increment and decrement start from the effective value when unset")
    func progressFromEffectiveValue() {
        let editor = TestEditor(defaultLimit: 1.5)
        editor.limit.increment()
        #expect(editor.preferences.limit == 1.75)

        let editor2 = TestEditor(defaultLimit: 1.5)
        editor2.limit.decrement()
        #expect(editor2.preferences.limit == 1.25)
    }

    @Test("increment and decrement start from the default value when the effective value is nil")
    func progressFromDefaultValue() {
        let editor = TestEditor()
        editor.limit.increment()
        #expect(editor.preferences.limit == 1.25)

        let editor2 = TestEditor()
        editor2.limit.decrement()
        #expect(editor2.preferences.limit == 0.75)
    }

    @Test("increment and decrement stay in the supported range")
    func progressIsClamped() {
        let editor = TestEditor(preferences: TestPreferences(limit: 2.0))
        editor.limit.increment()
        #expect(editor.preferences.limit == 2.0)

        editor.limit.set(0.5)
        editor.limit.decrement()
        #expect(editor.preferences.limit == 0.5)
    }

    @Test("the type eraser forwards the range properties")
    func typeEraser() {
        let editor = TestEditor()
        let preference = editor.limit
        #expect(preference.supportedRange == 0.5 ... 2.0)
        #expect(preference.defaultValue == 1.0)
        #expect(preference.format(value: 1.5) == "150%")
    }

    @Test("isEffective is computed from the editor state")
    func isEffective() {
        let editor = TestEditor()
        #expect(editor.limit.isEffective)
        editor.isEnabled.set(false)
        #expect(!editor.limit.isEffective)
    }
}

private struct TestPreferences: ConfigurablePreferences {
    static let empty = TestPreferences()

    var limit: Double?
    var isEnabled: Bool?

    func merging(_ other: TestPreferences) -> TestPreferences {
        TestPreferences(
            limit: other.limit ?? limit,
            isEnabled: other.isEnabled ?? isEnabled
        )
    }
}

private struct TestSettings: ConfigurableSettings {
    var limit: Double?
    var isEnabled: Bool
}

private final class TestEditor: StatefulPreferencesEditor<TestPreferences, TestSettings> {
    init(preferences: TestPreferences = .empty, defaultLimit: Double? = nil) {
        super.init(initialPreferences: preferences) {
            TestSettings(
                limit: $0.limit ?? defaultLimit,
                isEnabled: $0.isEnabled ?? true
            )
        }
    }

    lazy var isEnabled: AnyPreference<Bool> = preference(
        preference: \.isEnabled,
        setting: \.isEnabled,
        defaultEffectiveValue: true,
        isEffective: { _ in true }
    )

    lazy var limit: AnyOptionalRangePreference<Double> = optionalRangePreference(
        preference: \.limit,
        setting: \.limit,
        defaultValue: 1.0,
        isEffective: { $0.settings.isEnabled },
        supportedRange: 0.5 ... 2.0,
        progressionStrategy: .increment(0.25),
        format: { "\(Int(($0 * 100).rounded()))%" }
    )
}
