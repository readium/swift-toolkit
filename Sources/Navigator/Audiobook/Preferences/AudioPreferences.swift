//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Preferences for the `AudioNavigator`.
public struct AudioPreferences: ConfigurablePreferences {
    public static let empty: AudioPreferences = .init()

    /// Volume of playback, from 0.0 to 1.0.
    public var volume: Double? {
        willSet { precondition(volume == nil || 0 ... 1 ~= volume!) }
    }

    /// Speed of playback.
    /// Normal is 1.0.
    public var speed: Double? {
        willSet { precondition(speed == nil || speed! >= 0) }
    }

    public init(
        volume: Double? = nil,
        speed: Double? = nil
    ) {
        precondition(volume == nil || 0 ... 1 ~= volume!)
        precondition(speed == nil || speed! >= 0)

        self.volume = volume
        self.speed = speed
    }

    public func merging(_ other: AudioPreferences) -> AudioPreferences {
        AudioPreferences(
            volume: other.volume ?? volume,
            speed: other.speed ?? speed
        )
    }

    /// Returns a new `AudioPreferences` with the publication-specific preferences
    /// removed.
    public func filterSharedPreferences() -> AudioPreferences {
        self
    }

    /// Returns a new `AudioPreferences` keeping only the publication-specific
    /// preferences.
    public func filterPublicationPreferences() -> AudioPreferences {
        AudioPreferences()
    }
}
