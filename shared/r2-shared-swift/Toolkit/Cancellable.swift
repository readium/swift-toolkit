//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A protocol indicating that an activity or action supports cancellation.
public protocol Cancellable {
    /// Cancel the on-going activity.
    func cancel()
}

/// A `Cancellable` object saving its cancelled state.
public final class CancellableObject: Cancellable {
    public private(set) var isCancelled = false

    public func cancel() {
        isCancelled = true
    }
}

extension DispatchQueue {
    func async(unlessCancelled cancellable: CancellableObject, execute work: @escaping () -> Void) {
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
public final class MediatorCancellable: Cancellable {
    private var cancellable: Cancellable?
    public private(set) var isCancelled = false

    public init(cancellable: Cancellable? = nil) {
        self.cancellable = cancellable
    }

    /// Switches the currently active cancellable which will receive the `cancel()` requests.
    public func mediate(_ cancellable: Cancellable) {
        if isCancelled {
            cancellable.cancel()
        } else {
            self.cancellable = cancellable
        }
    }

    public func cancel() {
        isCancelled = true
        cancellable?.cancel()
        cancellable = nil
    }
}
