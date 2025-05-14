//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

/// Represents a keyboard event emitted by a Navigator.
public struct KeyEvent: Equatable, CustomStringConvertible {
    /// Phase of this event, e.g. pressed or released.
    public var phase: Phase

    /// Key the user pressed or released.
    public var key: Key

    /// Additional key modifiers for keyboard shortcuts.
    public var modifiers: KeyModifiers

    public init(phase: Phase, key: Key, modifiers: KeyModifiers = []) {
        self.phase = phase
        self.key = key
        self.modifiers = modifiers
    }

    public var description: String {
        "\(phase) \(modifiers) \(key.description)"
    }

    /// Phase of a key event, e.g. pressed or released.
    public enum Phase: Equatable, CustomStringConvertible {
        case down
        case change
        case up
        case cancel

        public var description: String {
            switch self {
            case .down: "down"
            case .up: "up"
            case .change: "change"
            case .cancel: "cancel"
            }
        }
    }
}
