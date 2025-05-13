//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Utility for storing and managing a list of ``InputObserving`` objects.
///
/// The order of the observers is significant because a previous observer might
/// consume an event. When an event is consumed, the other observers will still
/// receive the event but with a `cancel` phase.
@MainActor
final class CompositeInputObserver: InputObservable, InputObserving {
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

    func didReceive(_ event: PointerEvent) async -> Bool {
        var handled = false
        var event = event

        for (_, observer) in observers {
            handled = await observer.didReceive(event)
            if handled {
                // Cancel the event for the other observers, as it was
                // handled by this one.
                event.phase = .cancel
            }
        }

        return handled
    }

    func didReceive(_ event: KeyEvent) async -> Bool {
        var handled = false
        var event = event

        for (_, observer) in observers {
            handled = await observer.didReceive(event)
            if handled {
                // Cancel the event for the other observers, as it was
                // handled by this one.
                event.phase = .cancel
            }
        }

        return handled
    }
}
