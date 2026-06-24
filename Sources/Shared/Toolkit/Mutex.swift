//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import os

// FIXME: iOS 16, use OSAllocatedUnfairLock as in https://gist.github.com/swhitty/571deb25d84c1954a7a01aafa661496e

/// A synchronization primitive that protects shared mutable state via mutual
/// exclusion.
///
/// Drop-in replacement for `Synchronization.Mutex` (iOS 18+) that works on iOS
/// 15+ with Swift 6 strict concurrency.
///
/// ```swift
/// class Manager {
///     let cache = Mutex<[String: Int]>([:])
///
///     func save(_ value: Int, for key: String) {
///         cache.withLock { $0[key] = value }
///     }
/// }
/// ```
@available(iOS, introduced: 15, deprecated: 18, message: "Use Mutex from the Synchronization module instead")
@frozen
public struct Mutex<Value: ~Copyable>: ~Copyable, Sendable {
    /// Single heap allocation holds both the lock and the value together.
    /// os_unfair_lock must never move after first use — the class guarantees a
    /// stable address for the lifetime of the Mutex.
    @usableFromInline
    final class Storage: Sendable {
        nonisolated(unsafe) var lock = os_unfair_lock()
        nonisolated(unsafe) var value: Value

        init(_ value: consuming Value) {
            self.value = value
        }
    }

    @usableFromInline
    let storage: Storage

    /// Initializes the mutex with the given initial value.
    public init(_ initialValue: consuming sending Value) {
        storage = Storage(initialValue)
    }

    /// Acquires the lock, calls `body` with an `inout` reference to the
    /// protected value, then releases the lock.
    @discardableResult
    public nonisolated borrowing func withLock<Result, Failure: Error>(
        _ body: (inout sending Value) throws(Failure) -> sending Result
    ) throws(Failure) -> sending Result {
        os_unfair_lock_lock(&storage.lock)
        defer { os_unfair_lock_unlock(&storage.lock) }
        return try body(&storage.value)
    }

    /// Tries to acquire the lock without blocking. If successful, calls `body`
    /// and returns its result; otherwise returns `nil` immediately.
    @discardableResult
    public nonisolated borrowing func withLockIfAvailable<Result, Failure: Error>(
        _ body: (inout sending Value) throws(Failure) -> sending Result
    ) throws(Failure) -> sending Result? {
        guard os_unfair_lock_trylock(&storage.lock) else { return nil }
        defer { os_unfair_lock_unlock(&storage.lock) }
        return try body(&storage.value)
    }
}
