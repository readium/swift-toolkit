//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation

public extension Future {
    /// Creates a `Future` which runs asynchronously on the given `queue`.
    convenience init(on queue: DispatchQueue, _ attemptToFulfill: @escaping @Sendable (@escaping Future<Output, Failure>.Promise) -> Void) {
        self.init { promise in
            // `Combine.Future.Promise` is not `Sendable`, but it is safe to
            // call from any thread, so we box it to hop onto `queue`.
            let box = UncheckedSendable(promise)
            queue.async {
                attemptToFulfill(box.value)
            }
        }
    }
}

/// Wraps a non-`Sendable` value to allow capturing it in a `@Sendable`
/// closure, when the value is known to be safe to transfer.
private nonisolated struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
