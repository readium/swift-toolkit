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
    mutating func addInputObserver(_ observer: InputObserving) -> InputObservableToken

    /// Unregisters an ``InputObserver`` from this receiver using the given
    /// `token` returned by `addInputObserver`.
    mutating func removeObserver(_ token: InputObservableToken)
}

/// A token which can be used to remove an ``InputObserver`` from an
/// ``InputObservable``.
public struct InputObservableToken: Hashable, Identifiable {
    public let id: AnyHashable

    public init(id: AnyHashable = UUID()) {
        self.id = id
    }
}
