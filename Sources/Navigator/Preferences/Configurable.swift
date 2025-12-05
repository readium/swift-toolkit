//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A `Configurable` is a component with a set of `ConfigurableSettings`.
public protocol Configurable {
    associatedtype Settings: ConfigurableSettings
    associatedtype Preferences: ConfigurablePreferences
    associatedtype Editor: PreferencesEditor where Editor.Preferences == Preferences

    /// Current `Settings` values.
    var settings: Settings { get }

    /// Submits a new set of `Preferences` to update the current `Settings`.
    ///
    /// Note that the `Configurable` might not update its `settings` right away, or might even
    /// ignore some of the provided preferences. They are only used as hints to compute the new
    /// settings.
    func submitPreferences(_ preferences: Preferences)

    /// Creates a `PreferencesEditor` helping build a user interface and modifying the given
    /// `preferences`.
    func editor(of preferences: Preferences) -> Editor
}

/// Marker interface for the setting properties holder.
public protocol ConfigurableSettings: Hashable {}

/// Marker interface for the `Preferences` properties holder.
public protocol ConfigurablePreferences: Codable, Hashable {
    /// Empty set of preferences.
    static var empty: Self { get }

    /// Creates a new instance of `Self` after merging the values of `other`.
    ///
    /// In case of conflict, `other` takes precedence.
    func merging(_ other: Self) -> Self
}

public extension Configurable {
    /// Wraps this `Configurable` with a type eraser.
    func eraseToAnyConfigurable() -> AnyConfigurable<Settings, Preferences, Editor> {
        AnyConfigurable(self)
    }
}

/// A type-erasing `Configurable` object.
public class AnyConfigurable<
    Settings: ConfigurableSettings,
    Preferences: ConfigurablePreferences,
    Editor: PreferencesEditor
>: Configurable where Editor.Preferences == Preferences {
    private let _settings: () -> Settings
    private let _submitPreferences: (Preferences) -> Void
    private let _editor: (Preferences) -> Editor

    init<C: Configurable>(_ configurable: C)
        where C.Settings == Settings, C.Preferences == Preferences, C.Editor == Editor
    {
        _settings = { configurable.settings }
        _submitPreferences = configurable.submitPreferences
        _editor = configurable.editor(of:)
    }

    public var settings: Settings { _settings() }

    public func submitPreferences(_ preferences: Preferences) {
        _submitPreferences(preferences)
    }

    public func editor(of preferences: Preferences) -> Editor {
        _editor(preferences)
    }
}
