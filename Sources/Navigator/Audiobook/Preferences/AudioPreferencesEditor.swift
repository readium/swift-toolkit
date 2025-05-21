//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Editor for a set of `AudioPreferences`.
///
/// Use `AudioPreferencesEditor` to assist you in building a preferences user
/// interface or modifying existing preferences. It includes rules for
/// adjusting preferences, such as the supported values or ranges.
public final class AudioPreferencesEditor: StatefulPreferencesEditor<AudioPreferences, AudioSettings> {
    private let defaults: AudioDefaults

    public init(initialPreferences: AudioPreferences, defaults: AudioDefaults) {
        self.defaults = defaults

        super.init(
            initialPreferences: initialPreferences,
            settings: { AudioSettings(preferences: $0, defaults: defaults) }
        )
    }

    /// Volume of playback, from 0.0 to 1.0.
    public lazy var volume: AnyRangePreference<Double> =
        rangePreference(
            preference: \.volume,
            setting: \.volume,
            defaultEffectiveValue: defaults.volume ?? 1.0,
            isEffective: { _ in true },
            supportedRange: 0.0 ... 1.0,
            progressionStrategy: .increment(0.1),
            format: \.percentageString
        )

    /// Speed of playback.
    /// Normal is 1.0.
    public lazy var speed: AnyRangePreference<Double> =
        rangePreference(
            preference: \.speed,
            setting: \.speed,
            defaultEffectiveValue: defaults.speed ?? 1.0,
            isEffective: { _ in true },
            supportedRange: 0.1 ... 6.0,
            progressionStrategy: .increment(0.1),
            format: \.percentageString
        )
}
