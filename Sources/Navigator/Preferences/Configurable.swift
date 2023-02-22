//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// A `Configurable` is a component with a set of `ConfigurableSettings`.
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
public protocol ConfigurableSettings {}

/// Marker interface for the `Preferences` properties holder.
public protocol ConfigurablePreferences: Codable, Equatable {

    /// Creates a new instance of `Self` after merging the values of `other`.
    ///
    /// In case of conflict, `other` takes precedence.
    func merging(_ other: Self) -> Self
}

extension Configurable {
    /// Wraps this `Configurable` with a type eraser.
    public func eraseToAnyConfigurable() -> AnyConfigurable<Settings, Preferences> {
        AnyConfigurable(self)
    }
}

/// A type-erasing `Configurable` object.
public class AnyConfigurable<Settings: ConfigurableSettings, Preferences: ConfigurablePreferences>: Configurable {

    private let getSettings: () -> Settings
    private let submit: (Preferences) -> Void

    init<C: Configurable>(_ configurable: C) where C.Settings == Settings, C.Preferences == Preferences {
        self.getSettings = { configurable.settings }
        self.submit = configurable.submitPreferences
    }

    public var settings: Settings { getSettings() }

    public func submitPreferences(_ preferences: Preferences) {
        submit(preferences)
    }
}
