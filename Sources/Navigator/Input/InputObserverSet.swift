//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

/// Utility to store and manage a set of ``InputObserver``.
struct InputObserverSet: InputObserver, InputObservable {
    private var observers: [InputObserverToken: InputObserver] = [:]

    mutating func addInputObserver(_ observer: any InputObserver) -> InputObserverToken {
        let token = InputObserverToken()
        precondition(observers[token] == nil)
        observers[token] = observer
        return token
    }

    mutating func removeObserver(_ token: InputObserverToken) {
        observers.removeValue(forKey: token)
    }

    func didReceive(_ event: PointerEvent) -> Bool {
        for (_, observer) in observers {
            if observer.didReceive(event) {
                return true
            }
        }
        return false
    }

    func didReceive(_ event: KeyEvent) -> Bool {
        for (_, observer) in observers {
            if observer.didReceive(event) {
                return true
            }
        }
        return false
    }
}
