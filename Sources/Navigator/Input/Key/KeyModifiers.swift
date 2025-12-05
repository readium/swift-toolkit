//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit

/// Represents a set of modifier keys held together.
public struct KeyModifiers: OptionSet, Equatable, CustomStringConvertible {
    public static let command = KeyModifiers(rawValue: 1 << 0)
    public static let control = KeyModifiers(rawValue: 1 << 1)
    public static let option = KeyModifiers(rawValue: 1 << 2)
    public static let shift = KeyModifiers(rawValue: 1 << 3)

    public var rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init?(key: Key) {
        switch key {
        case .command:
            self = .command
        case .control:
            self = .control
        case .option:
            self = .option
        case .shift:
            self = .shift
        default:
            return nil
        }
    }

    /// Returns the modifiers as keys.
    public var keys: [Key] {
        var keys: [Key] = []
        if contains(.command) {
            keys.append(.command)
        }
        if contains(.control) {
            keys.append(.control)
        }
        if contains(.option) {
            keys.append(.option)
        }
        if contains(.shift) {
            keys.append(.shift)
        }
        return keys
    }

    public var description: String {
        keys.map(\.description).joined(separator: "+")
    }
}
