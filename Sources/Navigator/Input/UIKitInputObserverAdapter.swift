//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit

@MainActor final class UIKitInputObserverAdapter {
    weak var view: UIView?
    private let observer: InputObserving

    init(observer: InputObserving) {
        self.observer = observer
    }

    // MARK: - Presses

    func on(_ phase: KeyEvent.Phase, presses: Set<UIPress>, with event: UIPressesEvent?) {
        Task {
            for press in presses {
                guard let event = KeyEvent(phase: phase, uiPress: press) else {
                    continue
                }
                _ = await observer.didReceive(event)
            }
        }
    }

    // MARK: - Touches

    func on(_ phase: PointerEvent.Phase, touches: Set<UITouch>, event: UIEvent?) {
        Task {
            for touch in touches {
                guard let view = view else {
                    continue
                }

                _ = await observer.didReceive(PointerEvent(
                    pointer: pointer(for: touch, with: event),
                    phase: phase,
                    location: touch.location(in: view),
                    modifiers: KeyModifiers(event: event)
                ))
            }
        }
    }

    private func pointer(for touch: UITouch, with event: UIEvent?) -> Pointer {
        let id = AnyHashable("UITouch.TouchType(\(touch.type))")

        return switch touch.type {
        case .direct, .indirect:
            .touch(TouchPointer(id: id))
        case .pencil, .indirectPointer:
            fallthrough
        @unknown default:
            .mouse(MousePointer(id: id, buttons: MouseButtons(event: event)))
        }
    }
}

public extension KeyEvent {
    init?(phase: KeyEvent.Phase, uiPress: UIPress) {
        guard
            let key = Key(uiPress: uiPress),
            var modifiers = KeyModifiers(uiPress: uiPress)
        else {
            return nil
        }

        if let modKey = KeyModifiers(key: key) {
            modifiers.remove(modKey)
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

private extension MouseButtons {
    init(event: UIEvent?) {
        self.init()

        guard let mask = event?.buttonMask else {
            return
        }

        if mask.contains(.primary) {
            insert(.main)
        }
        if mask.contains(.secondary) {
            insert(.secondary)
        }
    }
}

private extension KeyModifiers {
    init(event: UIEvent?) {
        self.init()

        guard let flags = event?.modifierFlags else {
            return
        }

        if flags.contains(.shift) {
            insert(.shift)
        }
        if flags.contains(.control) {
            insert(.control)
        }
        if flags.contains(.alternate) {
            insert(.option)
        }
        if flags.contains(.command) {
            insert(.command)
        }
    }

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
