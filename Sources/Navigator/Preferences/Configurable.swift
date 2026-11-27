//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A `Configurable` is a component with a set of `ConfigurableSettings`.
@MainActor
public protocol Configurable {
    associatedtype Settings: ConfigurableSettings
    associatedtype Preferences: ConfigurablePreferences

    /// Current `Settings` values.
    var settings: Settings { get }

    /// Submits a new set of `Preferences` to update the current `Settings`.
    ///
    /// Note that the `Configurable` might not update its `settings` right away, or might even
    /// ignore some of the provided preferences. They are only used as hints to compute the new
    /// settings.
    func submitPreferences(_ preferences: Preferences)

    /// Returns the `Settings` that this `Configurable` would apply if the
    /// given `preferences` were submitted.
    ///
    /// The settings are resolved with the `Configurable`'s own inputs, such
    /// as its publication, the reading order it renders and the defaults of
    /// its configuration, exactly like `submitPreferences(_:)` would do. The
    /// current `settings` are not affected.
    ///
    /// Use it to inspect the settings before, or without, submitting the
    /// preferences, for example to check which ones take effect with
    /// `isEffective(_:)` in a user settings interface.
    func settings(for preferences: Preferences) -> Settings
}

/// Setting values of a `Configurable`, resolved from its `Preferences`.
public protocol ConfigurableSettings: Hashable {
    /// Indicates whether the given `setting` would take effect if it was set
    /// by a preference, with the current publication and the other settings.
    ///
    /// Use it to disable the controls of the settings which have no effect.
    /// It doesn't tell whether the setting is set, as your own settings model
    /// already knows it.
    ///
    /// - Parameter setting: Key path of a stored setting, e.g. `\.scroll`.
    func isEffective(_ setting: PartialKeyPath<Self>) -> Bool
}

/// Marker interface for the `Preferences` properties holder.
public protocol ConfigurablePreferences: Hashable {
    /// Empty set of preferences.
    static var empty: Self { get }
}

public extension ConfigurablePreferences {
    @available(*, unavailable, message: "Store your own settings model and derive the preferences from it, see the migration guide")
    func merging(_ other: Self) -> Self {
        fatalError()
    }
}

public extension Configurable {
    /// Wraps this `Configurable` with a type eraser.
    func eraseToAnyConfigurable() -> AnyConfigurable<Settings, Preferences> {
        AnyConfigurable(self)
    }
}

/// A type-erasing `Configurable` object.
public final class AnyConfigurable<
    Settings: ConfigurableSettings,
    Preferences: ConfigurablePreferences
>: Configurable {
    private let _settings: () -> Settings
    private let _submitPreferences: (Preferences) -> Void
    private let _settingsForPreferences: (Preferences) -> Settings

    init<C: Configurable>(_ configurable: C)
        where C.Settings == Settings, C.Preferences == Preferences
    {
        _settings = { configurable.settings }
        _submitPreferences = configurable.submitPreferences
        _settingsForPreferences = configurable.settings(for:)
    }

    public var settings: Settings {
        _settings()
    }

    public func submitPreferences(_ preferences: Preferences) {
        _submitPreferences(preferences)
    }

    public func settings(for preferences: Preferences) -> Settings {
        _settingsForPreferences(preferences)
    }
}
