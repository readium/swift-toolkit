//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A type broadcasting user input events (e.g. touch or keyboard events) to
/// a set of observers.
public protocol InputObservable {
    /// Registers a new ``InputObserver`` for the observable receiver.
    ///
    /// - Returns: An opaque token which can be used to remove the observer with
    ///   `removeInputObserver`.
    @discardableResult
    mutating func addInputObserver(_ observer: InputObserver) -> InputObserverToken

    /// Unregisters an ``InputObserver`` from this receiver using the given
    /// `token` returned by `addInputObserver`.
    mutating func removeObserver(_ token: InputObserverToken)
}

/// A type observing user input events (e.g. touch or keyboard events)
/// broadcasted by an ``InputObservable`` instance.
public protocol InputObserver {
    /// Called when receiving a pointer event, such as a mouse click or a touch
    /// event.
    ///
    /// - Returns: Indicates whether this observer consumed the event, which
    /// will not be forwarded to other observers.
    func didReceive(_ event: PointerEvent) -> Bool

    /// Called when receiving a keyboard event.
    ///
    /// - Returns: Indicates whether this observer consumed the event, which
    /// will not be forwarded to other observers.
    func didReceive(_ event: KeyEvent) -> Bool
}

public extension InputObserver {
    func didReceive(_ event: PointerEvent) -> Bool { false }
    func didReceive(_ event: KeyEvent) -> Bool { false }
}

/// A token which can be used to remove an ``InputObserver`` from an
/// ``InputObservable``.
public struct InputObserverToken: Hashable, Identifiable {
    public let id: AnyHashable

    public init(id: AnyHashable = UUID()) {
        self.id = id
    }
}
