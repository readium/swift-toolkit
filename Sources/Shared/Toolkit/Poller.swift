//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

private final class Poller: Sendable {
    private let condition: @Sendable @MainActor () -> Bool
    private let pollingInterval: TimeInterval
    private let block: @Sendable @MainActor () async -> Void
    @MainActor private var isPolling = false

    init(
        condition: @escaping @Sendable @MainActor () -> Bool,
        pollingInterval: TimeInterval,
        block: @escaping @Sendable @MainActor () async -> Void
    ) {
        self.condition = condition
        self.pollingInterval = pollingInterval
        self.block = block
    }

    @MainActor
    func start() {
        guard !isPolling else { return }
        isPolling = true
        poll()
    }

    @MainActor
    private func poll() {
        guard condition() else {
            Task { @MainActor in
                let interval = max(0, pollingInterval)
                if interval > 0 {
                    do {
                        try await Task.sleep(seconds: interval)
                    } catch {
                        isPolling = false
                        return
                    }
                } else {
                    await Task.yield()
                }
                self.poll()
            }
            return
        }
        Task { @MainActor in
            defer { isPolling = false }
            await block()
        }
    }
}

/// Executes the given `block` if `condition` is true. Otherwise, retries every `pollingInterval`
/// seconds until `condition` gets true.
///
/// Additional calls are ignored while polling the condition.
public func execute(
    when condition: @escaping @Sendable @MainActor () -> Bool,
    pollingInterval: TimeInterval = 0,
    _ block: @escaping @Sendable @MainActor () async -> Void
) -> @Sendable @MainActor () -> Void {
    let poller = Poller(
        condition: condition,
        pollingInterval: pollingInterval,
        block: block
    )
    return {
        poller.start()
    }
}
