//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
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

    @Suite("Effective settings") struct Effective {
        private let settings = AudioSettings(preferences: AudioPreferences())

        @Test("are tested for every setting")
        func listsEverySetting() {
            #expect(Set(allSettings.map(\.name)) == Set(Mirror(reflecting: settings).children.compactMap(\.label)))
        }

        @Test("include every setting")
        func everySettingIsEffective() {
            #expect(allSettings.allSatisfy { settings.isEffective($0.keyPath) })
        }
    }

    @Suite("Settings resolved by the navigator") @MainActor struct NavigatorResolution {
        private let navigator = AudioNavigator(
            publication: Publication(manifest: Manifest(
                metadata: Metadata(conformsTo: [.audiobook], title: "Audiobook"),
                readingOrder: [Link(href: "track.wav", mediaType: .wav)]
            )),
            config: .init(defaults: AudioDefaults(volume: 0.5, speed: 1.5)),
            audioSession: NoopAudioSessionManager()
        )

        @Test("use the defaults of the configuration")
        func usesDefaults() {
            let settings = navigator.settings(for: AudioPreferences(speed: 2.0))
            #expect(settings.volume == 0.5)
            #expect(settings.speed == 2.0)
        }

        @Test("are applied unchanged by submitting the same preferences")
        func appliedBySubmitting() {
            let preferences = AudioPreferences(volume: 0.8)
            let resolved = navigator.settings(for: preferences)
            #expect(navigator.settings != resolved)

            navigator.submitPreferences(preferences)
            #expect(navigator.settings == resolved)
        }
    }
}

/// Every setting of `AudioSettings`, with its name.
private var allSettings: [(name: String, keyPath: PartialKeyPath<AudioSettings>)] {
    [
        ("speed", \.speed),
        ("volume", \.volume),
    ]
}
