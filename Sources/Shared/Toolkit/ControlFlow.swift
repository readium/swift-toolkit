//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// A collection of tools to manage the Flow of Control.

/// Throttles the given `block` so that it is executed in `duration` seconds, ignoring additional
/// calls until then.
public func throttle(duration: TimeInterval = 0, on queue: DispatchQueue = .main, _ block: @escaping () -> Void) -> () -> Void {
    var throttling = false
    return {
        guard !throttling else {
            return
        }
        throttling = true

        queue.asyncAfter(deadline: .now() + duration) {
            throttling = false
            block()
        }
    }
}

/// Executes the given `block` if `condition` is true. Otherwise, retries every `pollingInterval`
/// seconds until `condition` gets true.
///
/// Additional calls are ignored while polling the condition.
public func execute(
    when condition: @escaping () -> Bool,
    pollingInterval: TimeInterval = 0,
    on queue: DispatchQueue = .main,
    _ block: @escaping () async -> Void
) -> () -> Void {
    var polling = false
    return {
        guard !polling else {
            return
        }

        func poll() {
            guard condition() else {
                polling = true
                queue.asyncAfter(deadline: .now() + pollingInterval, execute: poll)
                return
            }
            polling = false
            Task {
                await block()
            }
        }

        poll()
    }
}
