//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A protocol indicating that an activity or action supports cancellation.
public protocol Cancellable: Sendable {
    /// Cancel the on-going activity.
    func cancel()
}

/// A `Cancellable` object saving its cancelled state.
public final class CancellableObject: Cancellable, Sendable {
    private let state: Mutex<(isCancelled: Bool, onCancel: @Sendable () -> Void)>

    public var isCancelled: Bool {
        state.withLock { $0.isCancelled }
    }

    public init(onCancel: @escaping @Sendable () -> Void = {}) {
        state = Mutex((isCancelled: false, onCancel: onCancel))
    }

    public func cancel() {
        let blockToCall = state.withLock { state -> (@Sendable () -> Void)? in
            guard !state.isCancelled else {
                return nil
            }
            state.isCancelled = true
            let block = state.onCancel
            state.onCancel = {}
            return block
        }
        blockToCall?()
    }
}

extension DispatchQueue {
    func async(unlessCancelled cancellable: CancellableObject, execute work: @escaping @Sendable () -> Void) {
        async {
            guard !cancellable.isCancelled else {
                return
            }
            work()
        }
    }
}

/// A `Cancellable` acting as a proxy to underlying cancellables. The owner can switch the currently active cancellable
/// with `mediate()`.
///
/// In practice, this is useful when a task needs to return a single `Cancellable`, but might spawn multiple subtasks.
public final class MediatorCancellable: Cancellable, Sendable {
    private let state: Mutex<(cancellable: (any Cancellable)?, isCancelled: Bool)>

    public var isCancelled: Bool {
        state.withLock { $0.isCancelled }
    }

    public init(cancellable: (any Cancellable)? = nil) {
        state = Mutex((cancellable: cancellable, isCancelled: false))
    }

    /// Switches the currently active cancellable which will receive the `cancel()` requests.
    public func mediate(_ cancellable: any Cancellable) {
        let cancelImmediately = state.withLock { state in
            if state.isCancelled {
                return true
            } else {
                state.cancellable = cancellable
                return false
            }
        }
        if cancelImmediately {
            cancellable.cancel()
        }
    }

    public func cancel() {
        let cancellableToCancel = state.withLock { state in
            state.isCancelled = true
            let c = state.cancellable
            state.cancellable = nil
            return c
        }
        cancellableToCancel?.cancel()
    }
}

public extension Cancellable {
    /// Convenience to mediate a cancellable in a call chain.
    ///
    /// ```
    /// apiReturningACancellable()
    ///     .mediate(by: mediator)
    /// ```
    func mediated(by mediator: MediatorCancellable) {
        mediator.mediate(self)
    }
}
