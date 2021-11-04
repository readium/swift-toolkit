//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation

extension Future {
    /// Creates a `Future` which runs asynchronously on the given `queue`.
    public convenience init(on queue: DispatchQueue, _ attemptToFulfill: @escaping (@escaping Future<Output, Failure>.Promise) -> Void) {
        self.init { promise in
            queue.async {
                attemptToFulfill(promise)
            }
        }
    }
}
