//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a pointer event (e.g. touch, mouse) emitted by a navigator.
public struct PointerEvent: Equatable {
    /// Pointer causing this event.
    public var pointer: Pointer

    /// Phase of this event, e.g. up or move.
    public var phase: Phase

    /// Location of the pointer event relative to the navigator's view.
    public var location: CGPoint

    /// Key modifiers pressed alongside the pointer.
    public var modifiers: KeyModifiers

    /// Phase of a pointer event.
    public enum Phase: Equatable, CustomStringConvertible {
        /// Fired when a pointer becomes active.
        case down

        /// Fired when a pointer changes coordinates. This event is also used if
        /// the change in pointer state cannot be reported by other events.
        case move

        /// Fired when a pointer is no longer active.
        case up

        /// Fired if the navigator cannot generate more events for this pointer,
        /// for example because the interaction was captured by the system.
        case cancel

        public var description: String {
            switch self {
            case .down: "down"
            case .move: "move"
            case .up: "up"
            case .cancel: "cancel"
            }
        }
    }
}

/// Represents a pointer device, such as a mouse or a physical touch.
public enum Pointer: Equatable, CustomStringConvertible {
    case touch(TouchPointer)
    case mouse(MousePointer)

    /// Unique identifier for this pointer.
    public var id: AnyHashable {
        switch self {
        case let .touch(pointer): pointer.id
        case let .mouse(pointer): pointer.id
        }
    }

    /// Type of the pointer.
    public var type: PointerType {
        switch self {
        case .touch: .touch
        case .mouse: .mouse
        }
    }

    public var description: String {
        switch self {
        case let .touch(pointer):
            return "touch (\(pointer.id))"
        case let .mouse(pointer):
            return "mouse (\(pointer.id)) \(pointer.buttons)"
        }
    }
}

/// Type of a pointer.
public enum PointerType: Equatable, CaseIterable {
    case touch
    case mouse
}

/// Represents a physical touch pointer.
public struct TouchPointer: Identifiable, Equatable {
    /// Unique identifier for this pointer.
    public let id: AnyHashable

    public init(id: AnyHashable) {
        self.id = id
    }
}

/// Represents a mouse pointer.
public struct MousePointer: Identifiable, Equatable {
    /// Unique identifier for this pointer.
    public let id: AnyHashable

    /// Indicates which buttons are pressed on the mouse.
    public let buttons: MouseButtons

    public init(id: AnyHashable, buttons: MouseButtons) {
        self.id = id
        self.buttons = buttons
    }
}

/// Represents a set of mouse buttons.
///
/// The values are derived from https://developer.mozilla.org/en-US/docs/Web/API/MouseEvent/buttons#value
public struct MouseButtons: OptionSet, Equatable, CustomStringConvertible {
    /// Main button, usually the left button.
    public static let main = MouseButtons(rawValue: 1 << 0)

    /// Secondary button, usually the right button.
    public static let secondary = MouseButtons(rawValue: 1 << 1)

    /// Auxiliary button, usually the wheel button or the middle button.
    public static let auxiliary = MouseButtons(rawValue: 1 << 2)

    /// 4th button (typically the "Browser Back" button).
    public static let fourth = MouseButtons(rawValue: 1 << 3)

    /// 5th button (typically the "Browser Forward" button)
    public static let fifth = MouseButtons(rawValue: 1 << 4)

    public var rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public var description: String {
        var buttons: [String] = []
        if contains(.main) {
            buttons.append("main")
        }
        if contains(.secondary) {
            buttons.append("secondary")
        }
        if contains(.auxiliary) {
            buttons.append("auxiliary")
        }
        if contains(.fourth) {
            buttons.append("fourth")
        }
        if contains(.fifth) {
            buttons.append("fifth")
        }

        guard !buttons.isEmpty else {
            return "[]"
        }

        return "[" + buttons.joined(separator: ",") + "]"
    }
}
