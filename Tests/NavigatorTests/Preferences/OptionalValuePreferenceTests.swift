//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumNavigator
import Testing

/// Preferences whose value is itself optional, where `nil` is a valid
/// setting (e.g. an automatic number of columns).
@MainActor struct OptionalValuePreferenceTests {
    @Test("value is nil when unset, not .some(nil), and the effective value falls back on the defaults")
    func valueIsNilWhenUnset() {
        let editor = TestEditor(defaultCount: 2)
        #expect(editor.count.value == nil)
        #expect(editor.count.effectiveValue == 2)
        #expect(editor.enumCount.value == nil)
        #expect(editor.enumCount.effectiveValue == 2)
    }

    @Test("setting a value updates the preferences")
    func setValue() {
        let editor = TestEditor(defaultCount: 2)
        editor.count.set(1)
        #expect(editor.count.value == 1)
        #expect(editor.preferences.count == 1)

        editor.enumCount.set(3)
        #expect(editor.enumCount.value == 3)
        #expect(editor.preferences.enumCount == 3)
    }

    @Test("setting nil unsets the preference", arguments: [nil, .some(nil)] as [Int??])
    func setNil(value: Int??) {
        let editor = TestEditor(preferences: TestPreferences(count: 1, enumCount: 1), defaultCount: 2)
        editor.count.set(value)
        #expect(editor.count.value == nil)
        #expect(editor.count.effectiveValue == 2)

        editor.enumCount.set(value)
        #expect(editor.enumCount.value == nil)
        #expect(editor.enumCount.effectiveValue == 2)
    }
}

private struct TestPreferences: ConfigurablePreferences {
    static let empty = TestPreferences()

    var count: Int?
    var enumCount: Int?

    func merging(_ other: TestPreferences) -> TestPreferences {
        TestPreferences(
            count: other.count ?? count,
            enumCount: other.enumCount ?? enumCount
        )
    }
}

private struct TestSettings: ConfigurableSettings {
    var count: Int?
    var enumCount: Int?
}

private final class TestEditor: StatefulPreferencesEditor<TestPreferences, TestSettings> {
    init(preferences: TestPreferences = .empty, defaultCount: Int? = nil) {
        super.init(initialPreferences: preferences) {
            TestSettings(
                count: $0.count ?? defaultCount,
                enumCount: $0.enumCount ?? defaultCount
            )
        }
    }

    lazy var count: AnyPreference<Int?> = preference(
        preference: \.count,
        setting: \.count,
        isEffective: { _ in true }
    )

    lazy var enumCount: AnyEnumPreference<Int?> = enumPreference(
        preference: \.enumCount,
        setting: \.enumCount,
        isEffective: { _ in true },
        supportedValues: [nil, 1, 2, 3]
    )
}
