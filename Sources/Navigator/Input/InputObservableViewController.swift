//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit

/// Base implementation of ``UIViewController`` which implements
/// ``InputObservable`` to forward UIKit touches and presses events to
/// observers.
open class InputObservableViewController: UIViewController, InputObservable {
    let inputObservers = CompositeInputObserver()

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        becomeFirstResponder()
    }

    // MARK: - InputObservable

    @discardableResult
    public func addObserver(_ observer: any InputObserving) -> InputObservableToken {
        inputObservers.addObserver(observer)
    }

    public func removeObserver(_ token: InputObservableToken) {
        inputObservers.removeObserver(token)
    }

    // MARK: - UIResponder

    override open var canBecomeFirstResponder: Bool { true }

    override open func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if isFirstResponder {
            on(.down, presses: presses, with: event)
        } else {
            super.pressesBegan(presses, with: event)
        }
    }

    override open func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if isFirstResponder {
            on(.change, presses: presses, with: event)
        } else {
            super.pressesChanged(presses, with: event)
        }
    }

    override open func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if isFirstResponder {
            on(.cancel, presses: presses, with: event)
        } else {
            super.pressesCancelled(presses, with: event)
        }
    }

    override open func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if isFirstResponder {
            on(.up, presses: presses, with: event)
        } else {
            super.pressesEnded(presses, with: event)
        }
    }

    private func on(_ phase: KeyEvent.Phase, presses: Set<UIPress>, with event: UIPressesEvent?) {
        Task {
            for press in presses {
                guard let event = KeyEvent(phase: phase, uiPress: press) else {
                    continue
                }
                _ = await inputObservers.didReceive(event)
            }
        }
    }

    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        on(.down, touches: touches, event: event)
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        on(.move, touches: touches, event: event)
    }

    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        on(.cancel, touches: touches, event: event)
    }

    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        on(.up, touches: touches, event: event)
    }

    private func on(_ phase: PointerEvent.Phase, touches: Set<UITouch>, event: UIEvent?) {
        Task {
            for touch in touches {
                guard let view = view else {
                    continue
                }

                _ = await inputObservers.didReceive(PointerEvent(
                    pointer: Pointer(touch: touch, event: event),
                    phase: phase,
                    location: touch.location(in: view),
                    modifiers: KeyModifiers(event: event)
                ))
            }
        }
    }
}

extension Pointer {
    init(touch: UITouch, event: UIEvent?) {
        let id = AnyHashable(ObjectIdentifier(touch))

        self = switch touch.type {
        case .direct, .indirect:
            .touch(TouchPointer(id: id))
        case .pencil, .indirectPointer:
            .mouse(MousePointer(id: id, buttons: MouseButtons(event: event)))
        @unknown default:
            .mouse(MousePointer(id: id, buttons: MouseButtons(event: event)))
        }
    }
}

extension KeyEvent {
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

extension Key {
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

extension MouseButtons {
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

extension KeyModifiers {
    init(event: UIEvent?) {
        if let flags = event?.modifierFlags {
            self.init(flags: flags)
        } else {
            self.init()
        }
    }

    init(flags: UIKeyModifierFlags) {
        self.init()

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
