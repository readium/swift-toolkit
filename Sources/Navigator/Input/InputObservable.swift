//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A type broadcasting user input events (e.g. touch or keyboard events) to
/// a set of observers.
@MainActor public protocol InputObservable {
    /// Registers a new ``InputObserver`` for the observable receiver.
    ///
    /// - Returns: An opaque token which can be used to remove the observer with
    ///   `removeInputObserver`.
    @discardableResult
    func addObserver(_ observer: InputObserving) -> InputObservableToken

    /// Unregisters an ``InputObserver`` from this receiver using the given
    /// `token` returned by `addInputObserver`.
    func removeObserver(_ token: InputObservableToken)
}

/// A token which can be used to remove an ``InputObserver`` from an
/// ``InputObservable``.
public struct InputObservableToken: Hashable, Identifiable {
    public let id: AnyHashable

    public init(id: AnyHashable = UUID()) {
        self.id = id
    }

    /// Stores the receiver in the given `set` of tokens.
    public func store(in set: inout Set<InputObservableToken>) {
        set.insert(self)
    }
}
