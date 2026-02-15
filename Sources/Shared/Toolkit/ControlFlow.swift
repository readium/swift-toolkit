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
    final class State: @unchecked Sendable {
        private var isThrottling = false
        private let lock = NSLock()
        
        func run(duration: TimeInterval, queue: DispatchQueue, block: @escaping @Sendable () -> Void) {
            lock.lock()
            if isThrottling {
                lock.unlock()
                return
            }
            isThrottling = true
            lock.unlock()
            
            queue.asyncAfter(deadline: .now() + duration) {
                self.lock.lock()
                self.isThrottling = false
                self.lock.unlock()
                block()
            }
        }
    }
    
    let state = State()
    return {
        state.run(duration: duration, queue: queue, block: block)
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
    final class State: @unchecked Sendable {
        private var isPolling = false
        private let lock = NSLock()
        
        func run(
            condition: @escaping @Sendable () -> Bool,
            pollingInterval: TimeInterval,
            queue: DispatchQueue,
            block: @escaping @Sendable () async -> Void
        ) {
            lock.lock()
            if isPolling {
                lock.unlock()
                return
            }
            isPolling = true
            lock.unlock()
            
            poll(condition: condition, pollingInterval: pollingInterval, queue: queue, block: block)
        }
        
        private func poll(
            condition: @escaping @Sendable () -> Bool,
            pollingInterval: TimeInterval,
            queue: DispatchQueue,
            block: @escaping @Sendable () async -> Void
        ) {
            if condition() {
                lock.lock()
                isPolling = false
                lock.unlock()
                
                Task {
                    await block()
                }
            } else {
                queue.asyncAfter(deadline: .now() + pollingInterval) {
                    self.poll(
                        condition: condition,
                        pollingInterval: pollingInterval,
                        queue: queue,
                        block: block
                    )
                }
            }
        }
    }
    
    let state = State()
    return {
        state.run(condition: condition, pollingInterval: pollingInterval, queue: queue, block: block)
    }
}
