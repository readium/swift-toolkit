//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumNavigator
import Testing

enum AudioSettingsTests {
    @Suite("Resolving the settings") struct Resolution {
        @Test("falls back on 1.0 when nothing is set")
        func unset() {
            let settings = AudioSettings(preferences: AudioPreferences())
            #expect(settings.volume == 1.0)
            #expect(settings.speed == 1.0)
        }

        @Test("prefers the preferences, then the defaults")
        func precedence() {
            let defaults = AudioDefaults(volume: 0.5, speed: 1.5)
            let fromDefaults = AudioSettings(preferences: AudioPreferences(), defaults: defaults)
            #expect(fromDefaults.volume == 0.5)
            #expect(fromDefaults.speed == 1.5)

            let fromPreferences = AudioSettings(preferences: AudioPreferences(volume: 0.8, speed: 2.0), defaults: defaults)
            #expect(fromPreferences.volume == 0.8)
            #expect(fromPreferences.speed == 2.0)
        }
    }
}
