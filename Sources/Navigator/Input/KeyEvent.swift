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
    public let phase: Phase

    /// Key the user pressed or released.
    public let key: Key

    /// Additional key modifiers for keyboard shortcuts.
    public let modifiers: KeyModifiers

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

public enum Key: Equatable, CustomStringConvertible {
    // Printable character.
    case character(String)

    // Whitespace keys.
    case enter
    case tab
    case space

    // Navigation keys.
    case arrowDown
    case arrowLeft
    case arrowRight
    case arrowUp
    case end
    case home
    case pageDown
    case pageUp

    // Modifier keys.
    case command
    case control
    case option
    case shift

    // Others
    case backspace
    case escape

    /// Indicates whether this key is a modifier key.
    public var isModifier: Bool {
        KeyModifiers(key: self) != nil
    }

    public var description: String {
        switch self {
        case let .character(character):
            return character
        case .enter:
            return "Enter"
        case .tab:
            return "Tab"
        case .space:
            return "Spacebar"
        case .arrowDown:
            return "ArrowDown"
        case .arrowLeft:
            return "ArrowLeft"
        case .arrowRight:
            return "ArrowRight"
        case .arrowUp:
            return "ArrowUp"
        case .end:
            return "End"
        case .home:
            return "Home"
        case .pageDown:
            return "PageDown"
        case .pageUp:
            return "PageUp"
        case .command:
            return "Command"
        case .control:
            return "Control"
        case .option:
            return "Option"
        case .shift:
            return "Shift"
        case .backspace:
            return "Backspace"
        case .escape:
            return "Escape"
        }
    }
}

// MARK: - UIKit extensions

public extension KeyEvent {
    init?(uiPress: UIPress) {
        guard
            let key = Key(uiPress: uiPress),
            var modifiers = KeyModifiers(uiPress: uiPress)
        else {
            return nil
        }

        if let modKey = KeyModifiers(key: key) {
            modifiers.remove(modKey)
        }

        let phase: Phase = switch uiPress.phase {
        case .began: .down
        case .changed, .stationary: .change
        case .ended: .up
        case .cancelled: .cancel
        @unknown default: .change
        }

        self.init(phase: phase, key: key, modifiers: modifiers)
    }
}

public extension Key {
    init?(uiPress: UIPress) {
        guard let key = uiPress.key else {
            return nil
        }

        switch key.keyCode {
        case .keyboardReturnOrEnter, .keypadEnter:
            self = .enter
        case .keyboardTab:
            self = .tab
        case .keyboardSpacebar:
            self = .space
        case .keyboardDownArrow:
            self = .arrowDown
        case .keyboardUpArrow:
            self = .arrowUp
        case .keyboardLeftArrow:
            self = .arrowLeft
        case .keyboardRightArrow:
            self = .arrowRight
        case .keyboardEnd:
            self = .end
        case .keyboardHome:
            self = .home
        case .keyboardPageDown:
            self = .pageDown
        case .keyboardPageUp:
            self = .pageUp
        case .keyboardComma, .keypadComma:
            self = .command
        case .keyboardLeftControl, .keyboardRightControl:
            self = .control
        case .keyboardLeftAlt, .keyboardRightAlt:
            self = .option
        case .keyboardLeftShift, .keyboardRightShift:
            self = .shift
        case .keyboardEscape:
            self = .escape

        default:
            let character = key.charactersIgnoringModifiers
            guard character != "" else {
                return nil
            }
            self = .character(character)
        }
    }
}
