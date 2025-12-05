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
        onActivate: @MainActor @escaping (PointerEvent) async -> Bool
    ) -> ActivatePointerObserver {
        ActivatePointerObserver(
            modifiers: modifiers,
            shouldIgnore: {
                switch $0.pointer {
                case let .mouse(pointer):
                    return pointer.buttons != [] && pointer.buttons != .main
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
        onTap: @MainActor @escaping (PointerEvent) async -> Bool
    ) -> ActivatePointerObserver {
        ActivatePointerObserver(
            modifiers: modifiers,
            shouldIgnore: { $0.pointer.type != .touch },
            onActivate: onTap
        )
    }

    /// Recognizes a click event, if the given key `modifiers` and mouse
    /// `buttons` are pressed.
    static func click(
        buttons: MouseButtons = .main,
        modifiers: KeyModifiers = [],
        onClick: @MainActor @escaping (PointerEvent) async -> Bool
    ) -> ActivatePointerObserver {
        ActivatePointerObserver(
            modifiers: modifiers,
            shouldIgnore: {
                guard
                    case let .mouse(pointer) = $0.pointer,
                    pointer.buttons == buttons || (pointer.buttons == [] && buttons == .main)
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
@MainActor public final class ActivatePointerObserver: InputObserving, Loggable {
    private let modifiers: KeyModifiers
    private let shouldIgnore: @MainActor (PointerEvent) -> Bool
    private let onActivate: @MainActor (PointerEvent) async -> Bool

    public init(
        modifiers: KeyModifiers = [],
        shouldIgnore: @MainActor @escaping (PointerEvent) -> Bool,
        onActivate: @MainActor @escaping (PointerEvent) async -> Bool
    ) {
        self.modifiers = modifiers
        self.shouldIgnore = shouldIgnore
        self.onActivate = onActivate
    }

    private enum State {
        case idle
        case recognizing(id: AnyHashable, lastLocation: CGPoint)
        case recognized
        case failed(activePointers: Set<AnyHashable>)
    }

    private var state: State = .idle {
        didSet {
//            log(.info, "state \(state)")
        }
    }

    public func didReceive(_ event: PointerEvent) async -> Bool {
        let ignored = shouldIgnore(event)
//        log(.info, "on \(ignored ? "ignored " : "")\(event)")

        guard !ignored else {
            return false
        }

        state = transition(state: state, event: event)

        if case .recognized = state {
            state = .idle
            return await onActivate(event)
        }

        return false
    }

    public func didReceive(_ event: KeyEvent) async -> Bool {
        false
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
            return .recognized

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
