//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

@MainActor
public final class CancellableTasks {
    private var tasks: Set<Task<Void, Never>> = []

    public nonisolated init() {}

    public nonisolated func add(@_implicitSelfCapture _ task: @Sendable @escaping () async -> Void) {
        Task {
            await add(task)
        }
    }

    public func add(@_implicitSelfCapture _ task: @Sendable @escaping () async -> Void) async {
        let task = Task(operation: task)
        tasks.insert(task)
        _ = await task.value
        tasks.remove(task)
    }

    deinit {
        for task in tasks {
            task.cancel()
        }
    }
}

public extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
