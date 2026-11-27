//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Setting values of the `AudioNavigator`.
///
/// See `AudioPreferences`
public struct AudioSettings: ConfigurableSettings, Sendable {
    public let volume: Double
    public let speed: Double

    /// Resolves the settings applied by the audio navigator with the given
    /// `preferences`.
    ///
    /// A preference takes precedence over the `defaults`.
    ///
    /// - Parameters:
    ///   - defaults: Default values of the navigator, given in its
    ///     `AudioNavigator.Configuration`.
    init(preferences: AudioPreferences, defaults: AudioDefaults = AudioDefaults()) {
        volume = preferences.volume
            ?? defaults.volume
            ?? 1.0

        speed = preferences.speed
            ?? defaults.speed
            ?? 1.0
    }

    /// Every audio setting is always effective, see
    /// `ConfigurableSettings.isEffective(_:)`.
    public func isEffective(_ setting: PartialKeyPath<AudioSettings>) -> Bool {
        true
    }
}

/// Default setting values for the audio navigator.
///
/// These values will be used when no publication metadata or user preference takes precedence.
///
/// See `AudioPreferences`.
public struct AudioDefaults: Sendable {
    public var volume: Double?
    public var speed: Double?

    public init(
        volume: Double? = nil,
        speed: Double? = nil
    ) {
        self.volume = volume
        self.speed = speed
    }
}
