//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a `Result` which can be in a `cancelled` state.
public enum CancellableResult<Success, Failure: Error> {
    case success(Success)
    case failure(Failure)
    case cancelled

    public enum Error: Swift.Error {
        case cancelled
    }

    /// Creates a `CancelableResult` from a `Result`.
    public init(_ result: Result<Success, Failure>) {
        switch result {
        case let .success(value):
            self = .success(value)
        case let .failure(error):
            self = .failure(error)
        }
    }

    /// Creates a `CancelableResult` from a `Result` with the cancelled state represented as a `nil`
    /// success.
    public init(_ result: Result<Success?, Failure>) {
        switch result {
        case let .success(value):
            if let value = value {
                self = .success(value)
            } else {
                self = .cancelled
            }
        case let .failure(error):
            self = .failure(error)
        }
    }

    /// Gets a success result or throws an error.
    ///
    /// In case of cancellation, `Error.cancelled` is thrown.
    public func get() throws -> Success {
        switch self {
        case let .success(success):
            return success
        case let .failure(error):
            throw error
        case .cancelled:
            throw Error.cancelled
        }
    }

    /// Creates a `Result` with the cancelled state represented as a `Error.cancelled` failure.
    public var result: Result<Success, Swift.Error> {
        switch self {
        case let .success(success):
            return .success(success)
        case let .failure(error):
            return .failure(error)
        case .cancelled:
            return .failure(Error.cancelled)
        }
    }

    /// Creates a `Result` with a custom cancelled error.
    public func result(withCancelledError cancelledError: @autoclosure () -> Failure) -> Result<Success, Failure> {
        switch self {
        case let .success(success):
            return .success(success)
        case let .failure(error):
            return .failure(error)
        case .cancelled:
            return .failure(cancelledError())
        }
    }

    public func map<NewSuccess>(_ transform: (Success) -> NewSuccess) -> CancellableResult<NewSuccess, Failure> {
        switch self {
        case let .success(success):
            return .success(transform(success))
        case let .failure(error):
            return .failure(error)
        case .cancelled:
            return .cancelled
        }
    }

    public func mapCatching<NewSuccess>(_ transform: (Success) throws -> NewSuccess) -> CancellableResult<NewSuccess, Swift.Error> {
        switch self {
        case let .success(success):
            do {
                return try .success(transform(success))
            } catch {
                return .failure(error)
            }
        case let .failure(error):
            return .failure(error)
        case .cancelled:
            return .cancelled
        }
    }

    public func mapError<NewFailure: Swift.Error>(_ transform: (Failure) -> NewFailure) -> CancellableResult<Success, NewFailure> {
        switch self {
        case let .success(success):
            return .success(success)
        case let .failure(error):
            return .failure(transform(error))
        case .cancelled:
            return .cancelled
        }
    }

    /// Returns a `CancellableResult` with the same value, but typed with a generic `Error`.
    public func eraseToAnyError() -> CancellableResult<Success, Swift.Error> {
        mapError { $0 as Swift.Error }
    }
}

extension CancellableResult: Equatable where Success: Equatable, Failure: Equatable {}
