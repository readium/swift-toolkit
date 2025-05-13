//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

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

    public static let a: Key = .character("a")
    public static let b: Key = .character("b")
    public static let c: Key = .character("c")
    public static let d: Key = .character("d")
    public static let e: Key = .character("e")
    public static let f: Key = .character("f")
    public static let g: Key = .character("g")
    public static let h: Key = .character("h")
    public static let i: Key = .character("i")
    public static let j: Key = .character("j")
    public static let k: Key = .character("k")
    public static let l: Key = .character("l")
    public static let m: Key = .character("m")
    public static let n: Key = .character("n")
    public static let o: Key = .character("o")
    public static let p: Key = .character("p")
    public static let q: Key = .character("q")
    public static let r: Key = .character("r")
    public static let s: Key = .character("s")
    public static let t: Key = .character("t")
    public static let u: Key = .character("u")
    public static let v: Key = .character("v")
    public static let w: Key = .character("w")
    public static let x: Key = .character("x")
    public static let y: Key = .character("y")
    public static let z: Key = .character("z")
    public static let zero: Key = .character("0")
    public static let one: Key = .character("1")
    public static let two: Key = .character("2")
    public static let three: Key = .character("3")
    public static let four: Key = .character("4")
    public static let five: Key = .character("5")
    public static let six: Key = .character("6")
    public static let seven: Key = .character("7")
    public static let eight: Key = .character("8")
    public static let nine: Key = .character("9")
}
