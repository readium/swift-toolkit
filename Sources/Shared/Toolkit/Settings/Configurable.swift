//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A `Configurable` is a component with a set of `ConfigurableSettings`.
public protocol Configurable {
    associatedtype Settings: ConfigurableSettings

    /// Current `Settings` values.
    var settings: Observable<Settings> { get }

    /// Submits a new set of `Preferences` to update the current `Settings`.
    ///
    /// Note that the `Configurable` might not update its `settings` right away, or might even
    /// ignore some of the provided preferences. They are only used as hints to compute the new
    /// settings.
    func submitPreferences(_ preferences: Preferences)
}

/// Marker interface for the `Setting` properties holder.
public protocol ConfigurableSettings {}

public class AnyConfigurable<Settings: ConfigurableSettings>: Configurable {

    private let getSettings: () -> Observable<Settings>
    private let submit: (Preferences) -> Void

    init<C: Configurable>(_ configurable: C) where C.Settings == Settings {
        self.getSettings = { configurable.settings }
        self.submit = configurable.submitPreferences
    }

    public var settings: Observable<Settings> { getSettings() }

    public func submitPreferences(_ preferences: Preferences) {
        submit(preferences)
    }
}

extension Configurable {
    public func eraseToAnyConfigurable() -> AnyConfigurable<Settings> {
        AnyConfigurable(self)
    }
}
