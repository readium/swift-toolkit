//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// A collection of tools to manage the Flow of Control.

/// Throttles the given `block` so that it is executed in `duration` seconds, ignoring additional
/// calls until then.
public func throttle(
    duration: TimeInterval = 0,
    on queue: DispatchQueue = .main,
    _ block: @escaping @Sendable () -> Void
) -> @Sendable () -> Void {
    actor State {
        var isThrottling = false

        func attemptRun(duration: TimeInterval, queue: DispatchQueue, block: @escaping @Sendable () -> Void) {
            if isThrottling { return }
            isThrottling = true

            queue.asyncAfter(deadline: .now() + duration) {
                Task {
                    await self.reset()
                    block()
                }
            }
        }

        func reset() {
            isThrottling = false
        }
    }

    let state = State()
    return {
        Task { await state.attemptRun(duration: duration, queue: queue, block: block) }
    }
}

/// Executes the given `block` if `condition` is true. Otherwise, retries every `pollingInterval`
/// seconds until `condition` gets true.
///
/// Additional calls are ignored while polling the condition.
public func execute(
    when condition: @escaping @Sendable () -> Bool,
    pollingInterval: TimeInterval = 0,
    on queue: DispatchQueue = .main,
    _ block: @escaping @Sendable () async -> Void
) -> @Sendable () -> Void {
    actor State {
        var isPolling = false

        func run(
            condition: @escaping @Sendable () -> Bool,
            pollingInterval: TimeInterval,
            queue: DispatchQueue,
            block: @escaping @Sendable () async -> Void
        ) {
            if isPolling { return }
            isPolling = true
            poll(condition: condition, pollingInterval: pollingInterval, queue: queue, block: block)
        }

        private func poll(
            condition: @escaping @Sendable () -> Bool,
            pollingInterval: TimeInterval,
            queue: DispatchQueue,
            block: @escaping @Sendable () async -> Void
        ) {
            if condition() {
                isPolling = false
                Task { await block() }
            } else {
                queue.asyncAfter(deadline: .now() + pollingInterval) {
                    Task {
                        await self.poll(
                            condition: condition,
                            pollingInterval: pollingInterval,
                            queue: queue,
                            block: block
                        )
                    }
                }
            }
        }
    }

    let state = State()
    return {
        Task { await state.run(condition: condition, pollingInterval: pollingInterval, queue: queue, block: block) }
    }
}
