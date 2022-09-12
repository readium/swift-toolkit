//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A `SettingActivator` ensures that the condition required for a setting to be active are met in
/// a set of `Preferences`.
///
/// For example, the EPUB navigator requires the `SettingKey.publisherStyles` to be disabled to
/// render the `SettingKey.wordSpacing` setting.
public protocol SettingActivator {

    /// Indicates whether the setting is active in the given set of `preferences`.
    func isActive(with preferences: Preferences) -> Bool

    /// Updates the given `preferences` to make sure the setting is active.
    func activate(in preferences: inout Preferences)
}

/// Default implementation of `SettingActivator` for a setting that is always considered active.
public class NullSettingActivator: SettingActivator {
    public func isActive(with preferences: Preferences) -> Bool {true}
    public func activate(in preferences: inout Preferences) {}

    public init() {}
}

/// A `SettingActivator` combining two activators.
public class CombinedSettingActivator: SettingActivator {
    private let outer: SettingActivator
    private let inner: SettingActivator

    public init(outer: SettingActivator, inner: SettingActivator) {
        self.outer = outer
        self.inner = inner
    }

    public func isActive(with preferences: Preferences) -> Bool {
        inner.isActive(with: preferences) && outer.isActive(with: preferences)
    }

    public func activate(in preferences: inout Preferences) {
        inner.activate(in: &preferences)
        outer.activate(in: &preferences)
    }
}

extension SettingActivator {
    func combine(with other: SettingActivator) -> CombinedSettingActivator {
        CombinedSettingActivator(outer: self, inner: other)
    }
}
