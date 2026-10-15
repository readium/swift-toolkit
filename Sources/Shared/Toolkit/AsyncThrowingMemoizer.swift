//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

/// An actor that caches the first successful result of an asynchronous
/// computation.
///
/// Unlike ``AsyncMemoizer``, a failure is not cached: the next call computes
/// again. The calls made while a computation is running share its result.
///
/// Example:
/// ```swift
/// let memoizer = AsyncThrowingMemoizer { () async throws(ReadError) -> Data in
///     try await resource.read().get()
/// }
///
/// let data = try await memoizer()
/// ```
package actor AsyncThrowingMemoizer<Success: Sendable, Failure: Error> {
    private let compute: @Sendable () async throws(Failure) -> Success
    private var task: Task<Result<Success, Failure>, Never>?

    package init(_ compute: @escaping @Sendable () async throws(Failure) -> Success) {
        self.compute = compute
    }

    /// Returns the cached success, or computes it if not yet available.
    package func callAsFunction() async throws(Failure) -> Success {
        let task = task ?? Task { [compute] in
            do throws(Failure) {
                return try await .success(compute())
            } catch {
                return .failure(error)
            }
        }
        self.task = task

        let result = await task.value
        // Another call may have started a new computation in the meantime.
        if case .failure = result, self.task == task {
            self.task = nil
        }
        return try result.get()
    }

    deinit {
        task?.cancel()
    }
}
