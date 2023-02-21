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

public extension PreferencesEditor {
    /// A type-erasing wrapper for this `PreferencesEditor`.
    func eraseToAnyPreferencesEditor() -> AnyPreferencesEditor<Preferences> {
        AnyPreferencesEditor(self)
    }
}

/// A type-erasing `PreferencesEditor`.
public final class AnyPreferencesEditor<Preferences: ConfigurablePreferences>: PreferencesEditor {

    private let _preferences: () -> Preferences
    private let _clear: () -> Void

    init<E: PreferencesEditor>(_ editor: E) where E.Preferences == Preferences {
        self._preferences = { editor.preferences }
        self._clear = editor.clear
    }

    public var preferences: Preferences { _preferences() }

    public func clear() {
        _clear()
    }
}
