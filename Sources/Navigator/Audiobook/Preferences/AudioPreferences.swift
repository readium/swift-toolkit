//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Preferences for the `AudioNavigator`.
public struct AudioPreferences: ConfigurablePreferences, Sendable {
    public static let empty: AudioPreferences = .init()

    /// Volume of playback, from `0.0` to `1.0`.
    ///
    /// Accepted range: `0.0...1.0`, other values are a programming error.
    /// Suggested step: `0.1`.
    public var volume: Double? {
        willSet { precondition(newValue == nil || 0 ... 1 ~= newValue!) }
    }

    /// Speed of playback, greater than or equal to `0.0`. Normal is `1.0`.
    ///
    /// Accepted range: `0.0...`, negative values are a programming error.
    /// Suggested range: `0.1...6.0`, with a step of `0.1`.
    public var speed: Double? {
        willSet { precondition(newValue == nil || newValue! >= 0) }
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
}

public extension AudioPreferences {
    @available(*, unavailable, message: "Store the publication-specific settings in your own settings model, see the migration guide")
    func filterSharedPreferences() -> AudioPreferences {
        fatalError()
    }

    @available(*, unavailable, message: "Store the publication-specific settings in your own settings model, see the migration guide")
    func filterPublicationPreferences() -> AudioPreferences {
        fatalError()
    }
}

/// Decodes the `AudioPreferences` persisted with Readium 3.x, to migrate them
/// to your own settings model.
///
/// This is a snapshot of the 3.x `AudioPreferences`, with the values as they
/// were saved. The decoding is lenient: an invalid value drops only its
/// preference. The values are not checked against the ranges supported by
/// `AudioPreferences`.
///
/// It will be removed in a future major version.
public struct LegacyAudioPreferences: Decodable, Hashable, Sendable {
    /// Volume of playback, from 0.0 to 1.0.
    public let volume: Double?
    /// Speed of playback. Normal is 1.0.
    public let speed: Double?
}

public extension LegacyAudioPreferences {
    private enum CodingKeys: String, CodingKey {
        case volume
        case speed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        volume = container.decodeLeniently(Double.self, forKey: .volume)
        speed = container.decodeLeniently(Double.self, forKey: .speed)
    }
}
