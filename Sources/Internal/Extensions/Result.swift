//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Result {
    func getOrNil() -> Success? {
        try? get()
    }

    func get(or def: Success) -> Success {
        (try? get()) ?? def
    }

    func `catch`(_ recover: (Failure) -> Self) -> Self {
        if case let .failure(error) = self {
            return recover(error)
        }
        return self
    }

    func eraseToAnyError() -> Result<Success, Error> {
        mapError { $0 as Error }
    }

    /// Asynchronous variant of `map`.
    @inlinable func asyncMap<NewSuccess>(
        _ transform: (Success) async throws -> NewSuccess
    ) async rethrows -> Result<NewSuccess, Failure> {
        switch self {
        case let .success(success):
            return try await .success(transform(success))
        case let .failure(error):
            return .failure(error)
        }
    }

    /// Asynchronous variant of `flatMap`.
    @inlinable func asyncFlatMap<NewSuccess>(
        _ transform: (Success) async throws -> Result<NewSuccess, Failure>
    ) async rethrows -> Result<NewSuccess, Failure> {
        switch self {
        case let .success(success):
            return try await transform(success)
        case let .failure(error):
            return .failure(error)
        }
    }

    @inlinable func asyncRecover(
        _ catching: (Failure) async throws -> Self
    ) async rethrows -> Self {
        switch self {
        case let .success(success):
            return .success(success)
        case let .failure(error):
            return try await catching(error)
        }
    }

    @inlinable func combine<T>(_ other: Result<T, Failure>) -> Result<(Success, T), Failure> {
        flatMap { success in
            other.map { other in (success, other) }
        }
    }
}

public extension Result where Failure == Error {
    func tryMap<T>(_ transform: (Success) throws -> T) -> Result<T, Error> {
        flatMap {
            do {
                return try .success(transform($0))
            } catch {
                return .failure(error)
            }
        }
    }
}
