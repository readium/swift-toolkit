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

    public var description: String {
        var modifiers: [String] = []
        if contains(.command) {
            modifiers.append("Command")
        }
        if contains(.control) {
            modifiers.append("Control")
        }
        if contains(.option) {
            modifiers.append("Option")
        }
        if contains(.shift) {
            modifiers.append("Shift")
        }

        guard !modifiers.isEmpty else {
            return "[]"
        }

        return "[" + modifiers.joined(separator: ",") + "]"
    }
}

// MARK: - UIKit Extensions

public extension KeyModifiers {
    init?(uiPress: UIPress) {
        guard let flags = uiPress.key?.modifierFlags else {
            return nil
        }

        self = []

        if flags.contains(.shift) {
            insert(.shift)
        }
        if flags.contains(.command) {
            insert(.command)
        }
        if flags.contains(.control) {
            insert(.control)
        }
        if flags.contains(.alternate) {
            insert(.option)
        }
    }
}
