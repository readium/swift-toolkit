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

/// Utility for storing and managing a list of ``InputObserving`` objects.
///
/// The order of the observers is significant because a previous observer might
/// consume an event. When an event is consumed, the other observers will still
/// receive the event but with a `cancel` phase.
final class CompositeInputObserver: InputObservable {
    private typealias Observer = (token: InputObservableToken, observer: InputObserving)

    private var observers: [Observer] = []

    func addObserver(_ observer: any InputObserving) -> InputObservableToken {
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
