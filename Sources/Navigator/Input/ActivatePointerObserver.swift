//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public extension InputObserving where Self == ActivatePointerObserver {
    /// Recognizes a tap or (main) click input event, if the given key
    /// `modifiers` are pressed.
    static func activate(
        modifiers: KeyModifiers = [],
        _ onActivate: @escaping (PointerEvent) async -> Bool
    ) -> InputObserving {
        ActivatePointerObserver(
            modifiers: modifiers,
            shouldIgnore: {
                switch $0.pointer {
                case .mouse(let pointer):
                    return $0.phase != .up && pointer.buttons != [.main]
                case .touch:
                    return false
                }
            },
            onActivate: onActivate
        )
    }
    /// Recognizes a tap input event, if the given key `modifiers` are pressed.
    static func tap(
        modifiers: KeyModifiers = [],
        _ onTap: @escaping (PointerEvent) async -> Bool
    ) -> InputObserving {
        ActivatePointerObserver(
            modifiers: modifiers,
            shouldIgnore: { $0.pointer.type != .touch },
            onActivate: onTap
        )
    }

    /// Recognizes a click event, if the given key `modifiers` and mouse
    /// `buttons` are pressed.
    static func click(
        buttons: MouseButtons = [.main],
        modifiers: KeyModifiers = [],
        _ onClick: @escaping (PointerEvent) async -> Bool
    ) -> InputObserving {
        ActivatePointerObserver(
            modifiers: modifiers,
            shouldIgnore: {
                guard
                    case let .mouse(pointer) = $0.pointer,
                    $0.phase == .up || pointer.buttons == buttons
                else {
                    return true
                }
                return false
            },
            onActivate: onClick
        )
    }
}

/// Pointer observer recognizing a single button activation (e.g. a tap
/// or a click).
///
/// If multiple pointers are activated or the pointer moved (e.g. drag), the
/// activation is considered cancelled.
public actor ActivatePointerObserver: InputObserving, Loggable {
    private let modifiers: KeyModifiers
    private let shouldIgnore: (PointerEvent) -> Bool
    private let onActivate: (PointerEvent) async -> Bool

    public init(
        modifiers: KeyModifiers = [],
        shouldIgnore: @escaping (PointerEvent) -> Bool,
        onActivate: @escaping (PointerEvent) async -> Bool
    ) {
        self.modifiers = modifiers
        self.shouldIgnore = shouldIgnore
        self.onActivate = onActivate
    }

    private enum State {
        case idle
        case recognizing(id: AnyHashable, lastLocation: CGPoint)
        case recognized(event: PointerEvent)
        case failed(activePointers: Set<AnyHashable>)
    }

    private var state: State = .idle {
        didSet {
//            log(.trace, "state \(state)")
        }
    }

    public func didReceive(_ event: PointerEvent) async -> Bool {
        let ignored = shouldIgnore(event)
//        log(.trace, "on \(ignored ? "ignored " : "")\(event)")

        guard !ignored else {
            return false
        }

        state = transition(state: state, event: event)

        if case let .recognized(event) = state {
            let handled = await onActivate(event)
            state = .idle

            return handled
        }

        return false
    }

    private func transition(state: State, event: PointerEvent) -> State {
        let id = event.pointer.id

        switch (state, event.phase) {
        case (.idle, .down):
            if event.modifiers == modifiers {
                return .recognizing(id: event.pointer.id, lastLocation: event.location)
            } else {
                return .failed(activePointers: [id])
            }

        case let (.recognizing(recognizingID, _), .down) where recognizingID != id:
            return .failed(activePointers: [recognizingID, id])

        case let (.recognizing(recognizingID, _), .cancel) where recognizingID == id:
            return .idle

        case let (.recognizing(recognizingID, lastLocation), .move):
            if recognizingID != id || abs(lastLocation.x - event.location.x) > 1 || abs(lastLocation.y - event.location.y) > 1 {
                return .failed(activePointers: [recognizingID, id])
            } else {
                return .recognizing(id: recognizingID, lastLocation: event.location)
            }

        case let (.recognizing(recognizingID, _), .up) where recognizingID == id:
            return .recognized(event: event)

        case var (.failed(activePointers), .down):
            activePointers.insert(id)
            return .failed(activePointers: activePointers)

        case var (.failed(activePointers), .up),
             var (.failed(activePointers), .cancel):
            activePointers.remove(id)
            if activePointers.isEmpty {
                return .idle
            } else {
                return .failed(activePointers: activePointers)
            }

        default:
            return state
        }
    }
}
