//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension AsyncStream where Element: Sendable {
    /// Returns the next element matching `condition`, or `nil` when none
    /// arrives within `timeout` seconds.
    ///
    /// The elements buffered before the call are checked too. A timeout
    /// finishes the stream.
    func first(
        within timeout: TimeInterval,
        where condition: @escaping @Sendable (Element) -> Bool = { _ in true }
    ) async -> Element? {
        let iteration = Task { () -> Element? in
            for await element in self where condition(element) {
                return element
            }
            return nil
        }

        // Cancelling the iteration finishes the stream, which ends the wait.
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            iteration.cancel()
        }
        defer { timeoutTask.cancel() }

        return await iteration.value
    }
}
