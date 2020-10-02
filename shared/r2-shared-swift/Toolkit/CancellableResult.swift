//
//  CancellableResult.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 14/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Represents a `Result` which can be in a `canceled` state.
public enum CancellableResult<Success, Failure: Error> {
    case success(Success)
    case failure(Failure)
    case cancelled
    
    public enum Error: Swift.Error {
        case cancelled
    }
    
    /// Creates a `CancelableResult` from a `Result` with the canceled state represented as a `nil`
    /// success.
    public init(_ result: Result<Success?, Failure>) {
        switch result {
        case .success(let value):
            if let value = value {
                self = .success(value)
            } else {
                self = .cancelled
            }
        case .failure(let error):
            self = .failure(error)
        }
    }
    
    /// Gets a success result or throws an error.
    ///
    /// In case of cancellation, `Error.cancelled` is thrown.
    public func get() throws -> Success {
        switch self {
        case .success(let success):
            return success
        case .failure(let error):
            throw error
        case .cancelled:
            throw Error.cancelled
        }
    }
    
    /// Creates a `Result` with the canceled state represented as a `Error.cancelled` failure.
    public var result: Result<Success, Swift.Error> {
        switch self {
        case .success(let success):
            return .success(success)
        case .failure(let error):
            return .failure(error)
        case .cancelled:
            return .failure(Error.cancelled)
        }
    }
    
    public func map<NewSuccess>(_ transform: (Success) -> NewSuccess) -> CancellableResult<NewSuccess, Failure> {
        switch self {
        case .success(let success):
            return .success(transform(success))
        case .failure(let error):
            return .failure(error)
        case .cancelled:
            return .cancelled
        }
    }
    
    public func mapCatching<NewSuccess>(_ transform: (Success) throws -> NewSuccess) -> CancellableResult<NewSuccess, Swift.Error> {
        switch self {
        case .success(let success):
            do {
                return .success(try transform(success))
            } catch {
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        case .cancelled:
            return .cancelled
        }
    }
    
    public func mapError<NewFailure: Swift.Error>(_ transform: (Failure) -> NewFailure) -> CancellableResult<Success, NewFailure> {
        switch self {
        case .success(let success):
            return .success(success)
        case .failure(let error):
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

extension CancellableResult: Equatable where Success: Equatable, Failure: Equatable {
}
