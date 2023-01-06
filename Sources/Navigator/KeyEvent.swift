//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

public struct KeyEvent: Equatable, CustomStringConvertible {
    public let key: Key
    public let modifiers: KeyModifiers
    
    public init(key: Key, modifiers: KeyModifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }
    
    public init?(dict: [String: Any]) {
        guard let type = dict["type"] as? String,
              let code = dict["code"] as? String
        else {
            return nil
        }
        
        switch code {
            case "Enter":
                self.key = .enter
            case "Tab":
                self.key = .tab
            case "Space":
                self.key = .space
                
            case "ArrowDown":
                self.key = .arrowDown
            case "ArrowLeft":
                self.key = .arrowLeft
            case "ArrowRight":
                self.key = .arrowRight
            case "ArrowUp":
                self.key = .arrowUp
                
            case "End":
                self.key = .end
            case "Home":
                self.key = .home
            case "PageDown":
                self.key = .pageDown
            case "PageUp":
                self.key = .pageUp
                
            case "MetaLeft", "MetaRight":
                self.key = .command
            case "ControlLeft", "ControlRight":
                self.key = .control
            case "AltLeft", "AltRight":
                self.key = .option
            case "ShiftLeft", "ShiftRight":
                self.key = .shift
                
            case "Backspace":
                self.key = .backspace
                
            case _ where code.hasPrefix("Key") && code.count == 4:
                self.key = .character(code[code.index(before: code.endIndex)])
            default:
                return nil
        }
        
        switch type {
            case "keydown":
                var modifiers: KeyModifiers = []
                if let holdCommand = dict["command"] as? Int, holdCommand == 1 {
                    modifiers.rawValue = modifiers.rawValue | KeyModifiers.command.rawValue
                }
                if let holdControl = dict["control"] as? Int, holdControl == 1 {
                    modifiers.rawValue = modifiers.rawValue | KeyModifiers.control.rawValue
                }
                if let holdOption = dict["option"] as? Int, holdOption == 1 {
                    modifiers.rawValue = modifiers.rawValue | KeyModifiers.option.rawValue
                }
                if let holdShift = dict["shift"] as? Int, holdShift == 1 {
                    modifiers.rawValue = modifiers.rawValue | KeyModifiers.shift.rawValue
                }
                
                if self.key.isModifier, let modifier = self.key.toModifier {
                    modifiers.remove(modifier)
                }
                
                self.modifiers = modifiers
            case "keyup":
                self.modifiers = []
                
            default:
                return nil
        }
    }
    
    public var description: String {
        self.modifiers.description + " " + self.key.description
    }
}

public enum Key: Equatable, CustomStringConvertible {
    // Printable character.
    case character(Character)
    
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
    
    public var description: String {
        switch self {
            case .character(let character):
                return String(character)
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
        }
    }
    
    var isModifier: Bool {
        switch self {
            case .command, .control, .option, .shift:
                return true
                
            default:
                return false
        }
    }
    
    var toModifier: KeyModifiers? {
        switch self {
            case .command:
                return .command
            case .control:
                return .control
            case .option:
                return .option
            case .shift:
                return .shift
                
            default:
                return nil
        }
    }
}

public struct KeyModifiers: OptionSet {
    public var rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    var description: String {
        var modifiers: [String] = []
        if self.contains(.command) {
            modifiers.append("Command")
        }
        if self.contains(.control) {
            modifiers.append("Control")
        }
        if self.contains(.option) {
            modifiers.append("Option")
        }
        if self.contains(.shift) {
            modifiers.append("Shift")
        }
        
        guard !modifiers.isEmpty else {
            return "[]"
        }
        
        return "[" + modifiers.joined(separator: ",") + "]"
    }
    
    public static let command = KeyModifiers(rawValue: 1 << 0)
    public static let control = KeyModifiers(rawValue: 1 << 1)
    public static let option = KeyModifiers(rawValue: 1 << 2)
    public static let shift = KeyModifiers(rawValue: 1 << 3)
}

public extension UIPress {
    var modifiers: KeyModifiers {
        var modifiers: KeyModifiers = []
        
        if let flags = self.key?.modifierFlags, flags.rawValue != 0 {
            if flags.contains(.shift) {
                modifiers.rawValue = KeyModifiers.shift.rawValue | modifiers.rawValue
            }
            if flags.contains(.command) {
                modifiers.rawValue = KeyModifiers.command.rawValue | modifiers.rawValue
            }
            if flags.contains(.control) {
                modifiers.rawValue = KeyModifiers.control.rawValue | modifiers.rawValue
            }
            if flags.contains(.alternate) {
                modifiers.rawValue = KeyModifiers.option.rawValue | modifiers.rawValue
            }
        }
        
        return modifiers
    }
    
    var pressKey: Key? {
        guard let key = self.key else {
            return nil
        }
        
        switch key.keyCode {
            case .keyboardReturnOrEnter, .keypadEnter:
                return .enter
            case .keyboardTab:
                return .tab
            case .keyboardSpacebar:
                return .space
            case .keyboardDownArrow:
                return .arrowDown
            case .keyboardUpArrow:
                return .arrowUp
            case .keyboardLeftArrow:
                return .arrowLeft
            case .keyboardRightArrow:
                return .arrowRight
            case .keyboardEnd:
                return .end
            case .keyboardHome:
                return .home
            case .keyboardPageDown:
                return .pageDown
            case .keyboardPageUp:
                return .pageUp
            case .keyboardComma, .keypadComma:
                return .command
            case .keyboardLeftControl, .keyboardRightControl:
                return .control
            case .keyboardLeftAlt, .keyboardRightAlt:
                return .option
            case .keyboardLeftShift, .keyboardRightShift:
                return .shift
                
            default:
                let character = key.charactersIgnoringModifiers
                if character != "" {
                    return .character(character[character.startIndex])
                } else {
                    if key.modifierFlags.contains(.command) {
                        return .command
                    } else if key.modifierFlags.contains(.shift) {
                        return .shift
                    } else if key.modifierFlags.contains(.control) {
                        return .control
                    } else if key.modifierFlags.contains(.alternate) {
                        return .option
                    }
                }
        }
        
        return nil
    }
}
