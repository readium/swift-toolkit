//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// A collection of tools to manage the Flow of Control.

@MainActor
private final class ThrottlerState: Sendable {
    var isThrottling = false
}

/// Throttles the given `block` so that it is executed in `duration` seconds, ignoring additional
/// calls until then.
@MainActor
public func throttle(
    duration: TimeInterval = 0,
    _ block: @escaping @Sendable @MainActor () -> Void
) -> @Sendable @MainActor () -> Void {
    let state = ThrottlerState()
    return {
        guard !state.isThrottling else { return }
        state.isThrottling = true

        Task { @MainActor in
            defer { state.isThrottling = false }
            do {
                try await Task.sleep(seconds: max(0, duration))
            } catch {
                return
            }
            block()
        }
    }
}
