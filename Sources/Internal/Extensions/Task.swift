//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

public extension Task<Void, Never>? {
    /// Cancels the current task and starts a new one.
    mutating func replace(@_implicitSelfCapture with operation: sending @escaping @isolated(any) () async -> Void) {
        self?.cancel()
        self = Task(operation: operation)
    }

    /// Cancels and nils out the task.
    mutating func cancel() {
        self?.cancel()
        self = nil
    }
}
