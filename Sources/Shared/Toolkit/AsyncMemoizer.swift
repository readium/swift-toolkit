//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

/// An actor that caches the result of an asynchronous computation, ensuring it
/// runs only once.
///
/// Example:
/// ```swift
/// let memoizer = AsyncMemoizer<Data> {
///     await fetchDataFromNetwork()
/// }
///
/// let result = await memoizer()
/// ```
package actor AsyncMemoizer<T> {
    private let compute: @Sendable () async -> T
    private var task: Task<T, Never>?

    package init(_ compute: @escaping @Sendable () async -> T) {
        self.compute = compute
    }

    /// Returns the cached result or computes it if not yet available.
    package func callAsFunction() async -> T {
        if let task {
            return await task.value
        }
        let newTask = Task(operation: compute)
        task = newTask
        return await newTask.value
    }

    deinit {
        task?.cancel()
    }
}
