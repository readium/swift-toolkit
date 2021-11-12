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

public extension Cancellable {
    
    /// Returns a new cancellable which will automatically cancel `self` when deallocated.
    func cancelOnDeinit() -> Cancellable {
        AutoCancellable(self)
    }
    
    /// Stores this cancellable instance in the specified collection.
    func store<C>(in collection: inout C) where C : RangeReplaceableCollection, C.Element == Cancellable {
        collection.append(self)
    }
    
    /// Stores this cancellable instance in the specified variable.
    func store(in variable: inout Cancellable?) {
        variable = self
    }
}

/// A `Cancellable` object saving its cancelled state and running an optional closure
/// when cancelled.
public final class CancellableObject: Cancellable {
    public private(set) var isCancelled = false
    private let onCancel: (() -> Void)?
    
    public init(onCancel: (() -> Void)? = nil) {
        self.onCancel = onCancel
    }

    public func cancel() {
        if let onCancel = onCancel, !isCancelled {
            onCancel()
        }
        isCancelled = true
    }
}

/// A `Cancellable` which will run a given closure when cancelled.
public final class CancellableAction: Cancellable {
    public private(set) var isCancelled = false
    private let onCancel: () -> Void
    
    public init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

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

/// A `Cancellable` proxying another wrapped `cancellable`.
public class ProxyCancellable: Cancellable {
    
    private let cancellable: Cancellable
    
    public init(_ cancellable: Cancellable) {
        self.cancellable = cancellable
    }
    
    public func cancel() {
        cancellable.cancel()
    }
}

/// A `Cancellable` that is automatically cancelled when deallocated.
public final class AutoCancellable: ProxyCancellable {
    deinit {
        cancel()
    }
}
