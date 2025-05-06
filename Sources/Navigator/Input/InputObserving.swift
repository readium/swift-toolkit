//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A type observing user input events (e.g. touch or keyboard events)
/// broadcasted by an ``InputObservable`` instance.
public protocol InputObserving: Sendable {
    /// Called when receiving a pointer event, such as a mouse click or a touch
    /// event.
    ///
    /// - Returns: Indicates whether this observer consumed the event, which
    /// will not be forwarded to other observers.
    func didReceive(_ event: PointerEvent) async -> Bool

    /// Called when receiving a keyboard event.
    ///
    /// - Returns: Indicates whether this observer consumed the event, which
    /// will not be forwarded to other observers.
    func didReceive(_ event: KeyEvent) async -> Bool
}

public extension InputObserving {
    func didReceive(_ event: PointerEvent) async -> Bool { false }
    func didReceive(_ event: KeyEvent) async -> Bool { false }
}

public extension InputObserving where Self == TapObserver {
    static func tap(modifiers: KeyModifiers = [], _ onTap: @escaping (PointerEvent) async -> Bool) -> TapObserver {
        TapObserver(modifiers: modifiers, onTap: onTap)
    }
}

public actor TapObserver: InputObserving {
    private let modifiers: KeyModifiers
    private let onTap: (PointerEvent) async -> Bool

    public init(
        modifiers: KeyModifiers = [],
        onTap: @escaping (PointerEvent) async -> Bool
    ) {
        self.modifiers = modifiers
        self.onTap = onTap
    }

    /// Last location of the single active pointer.
    private var lastLocation: CGPoint? = nil

    /// Set of currently active pointer IDs.
    private var activePointers: Set<AnyHashable> = []

    /// True if a multitouch gesture has been detected (and should ignore tap).
    private var isMultitouch = false

    /// Indicates whether the touch moved enough to cancel the tap.
    private var hasMoved: Bool = false

    public func didReceive(_ event: PointerEvent) async -> Bool {
        guard case .touch = event.pointer else {
            return false
        }

        var handled = false

        switch event.phase {
        case .down:
            activePointers.insert(event.pointer.id)
            if activePointers.count > 1 {
                isMultitouch = true
            } else {
                lastLocation = event.location
            }

        case .move:
            guard !isMultitouch, !hasMoved, let lastLocation = lastLocation else {
                break
            }
            if abs(lastLocation.x - event.location.x) > 1 || abs(lastLocation.y - event.location.y) > 1 {
                hasMoved = true
            }

        case .up:
            activePointers.remove(event.pointer.id)

            // Only recognize tap if:
            // - This was not part of a multitouch gesture
            // - There are no more active pointers (all fingers up)
            if !isMultitouch, !hasMoved {
                handled = await onTap(event)
            }
        case .cancel:
            activePointers.remove(event.pointer.id)
        }

        // If all pointers are up, reset state.
        if activePointers.isEmpty {
            isMultitouch = false
            hasMoved = false
        }

        return handled
    }
}

/// Utility to store and manage a set of ``InputObserver``.
final class InputObservingSet: InputObservable {
    private typealias Observer = (token: InputObservableToken, observer: InputObserving)

    private var observers: [Observer] = []

    func addInputObserver(_ observer: any InputObserving) -> InputObservableToken {
        let token = InputObservableToken()
        precondition(!observers.contains { $0.token == token })
        observers.append(Observer(token: token, observer: observer))
        return token
    }

    func removeObserver(_ token: InputObservableToken) {
        observers.removeAll { $0.token == token }
    }

    func didReceive(_ event: PointerEvent) {
        Task {
            var event = event
            for (_, observer) in observers {
                if await observer.didReceive(event) {
                    // Cancel the event for the other observers, as it was
                    // handled by this one.
                    event.phase = .cancel
                }
            }
        }
    }

    func didReceive(_ event: KeyEvent) {
        Task {
            var event = event
            for (_, observer) in observers {
                if await observer.didReceive(event) {
                    // Cancel the event for the other observers, as it was
                    // handled by this one.
                    event.phase = .cancel
                }
            }
        }
    }
}
