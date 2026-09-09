//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Holds a set of tasks whose lifetime is bound to this instance: any task
/// still running when the instance is deallocated gets cancelled.
package final class CancellableTasks: Sendable {
    private let tasks = Mutex<[UUID: Task<Void, Never>]>([:])

    package init() {}

    package func add(@_implicitSelfCapture _ operation: @Sendable @escaping () async -> Void) {
        let id = UUID()
        tasks.withLock {
            // The task is registered while holding the lock, so its
            // self-removal cannot run before the registration.
            $0[id] = Task { [weak self] in
                await operation()
                self?.remove(id)
            }
        }
    }

    private func remove(_ id: UUID) {
        tasks.withLock {
            $0.removeValue(forKey: id)
        }
    }

    deinit {
        tasks.withLock {
            for task in $0.values {
                task.cancel()
            }
        }
    }
}
