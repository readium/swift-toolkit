//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// A collection of tools to manage the Flow of Control.

/// Throttles the given `block` so that it is executed in `duration` seconds, ignoring additional
/// calls until then.
public func throttle(duration: TimeInterval = 0, on queue: DispatchQueue = .main, _ block: @escaping @Sendable () -> Void) -> @Sendable () -> Void {
    let throttling = Mutex(false)
    return {
        let shouldExecute = throttling.withLock { isThrottling -> Bool in
            if isThrottling {
                return false
            } else {
                isThrottling = true
                return true
            }
        }
        guard shouldExecute else {
            return
        }

        queue.asyncAfter(deadline: .now() + duration) {
            throttling.withLock { $0 = false }
            block()
        }
    }
}
