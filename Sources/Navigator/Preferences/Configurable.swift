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
}

/// Marker interface for the setting properties holder.
public protocol ConfigurableSettings: Hashable {}

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

    init<C: Configurable>(_ configurable: C)
        where C.Settings == Settings, C.Preferences == Preferences
    {
        _settings = { configurable.settings }
        _submitPreferences = configurable.submitPreferences
    }

    public var settings: Settings {
        _settings()
    }

    public func submitPreferences(_ preferences: Preferences) {
        _submitPreferences(preferences)
    }
}
