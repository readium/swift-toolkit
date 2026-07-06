//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Holds a set of tasks whose lifetime is bound to this instance: any task
/// still running when the instance is deallocated gets cancelled.
public final class CancellableTasks: @unchecked Sendable {
    /// Guards `tasks`. `Mutex` lives in `ReadiumShared`, which depends on
    /// this module, hence the manual lock.
    private let lock = NSLock()
    private var tasks: [UUID: Task<Void, Never>] = [:]

    public init() {}

    public func add(@_implicitSelfCapture _ operation: @Sendable @escaping () async -> Void) {
        let id = UUID()
        lock.lock()
        defer { lock.unlock() }
        // The task is registered while holding the lock, so its self-removal
        // cannot run before the registration.
        tasks[id] = Task { [weak self] in
            await operation()
            self?.remove(id)
        }
    }

    private func remove(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        tasks.removeValue(forKey: id)
    }

    deinit {
        // No lock needed: reaching deinit means no other thread holds a
        // strong reference anymore, and the tasks only capture self weakly.
        for task in tasks.values {
            task.cancel()
        }
    }
}

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
