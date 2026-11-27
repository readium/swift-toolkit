//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// The preferences editors are removed: the app owns the preference values,
// and the settings tell which ones take effect with `isEffective(_:)`.

@available(*, unavailable, message: "Get the settings with EPUBNavigatorViewController.settings(for:) and check EPUBSettings.isEffective(_:), see the migration guide")
public final class EPUBPreferencesEditor {}

@available(*, unavailable, message: "Get the settings with PDFNavigatorViewController.settings(for:) and check PDFSettings.isEffective(_:), see the migration guide")
public final class PDFPreferencesEditor {}

@available(*, unavailable, message: "Get the settings with AudioNavigator.settings(for:) and check AudioSettings.isEffective(_:), see the migration guide")
public final class AudioPreferencesEditor {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public protocol PreferencesEditor {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public protocol Preference {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public protocol EnumPreference {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public protocol RangePreference {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public protocol OptionalRangePreference {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public class AnyPreference<Value> {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public final class AnyEnumPreference<Value> {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public final class AnyRangePreference<Value> {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public final class AnyOptionalRangePreference<Bound> {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public class StatefulPreferencesEditor<Preferences, Settings> {}

public extension AnyConfigurable {
    @available(*, unavailable, message: "Get the settings with settings(for:) and check their isEffective(_:), see the migration guide")
    func editor(of preferences: Preferences) -> any PreferencesEditor {
        fatalError()
    }
}
