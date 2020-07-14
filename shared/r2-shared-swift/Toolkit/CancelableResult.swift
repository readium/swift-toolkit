//
//  CancelableResult.swift
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
public enum CancelableResult<Success, Failure: Error> {
    case success(Success)
    case failure(Failure)
    case canceled
    
    /// Creates a `CancelableResult` from a `Result` with the canceled state represented as a `nil`
    /// success.
    public init(_ result: Result<Success?, Failure>) {
        switch result {
        case .success(let value):
            if let value = value {
                self = .success(value)
            } else {
                self = .canceled
            }
        case .failure(let error):
            self = .failure(error)
        }
    }
    
    /// Creates a `Result` with the canceled state represented as a `nil` success.
    public var result: Result<Success?, Failure> {
        switch self {
        case .success(let success):
            return .success(success)
        case .failure(let error):
            return .failure(error)
        case .canceled:
            return .success(nil)
        }
    }
    
    public func map<NewSuccess>(_ transform: (Success) -> NewSuccess) -> CancelableResult<NewSuccess, Failure> {
        switch self {
        case .success(let success):
            return .success(transform(success))
        case .failure(let error):
            return .failure(error)
        case .canceled:
            return .canceled
        }
    }
    
    public func mapError<NewFailure: Error>(_ transform: (Failure) -> NewFailure) -> CancelableResult<Success, NewFailure> {
        switch self {
        case .success(let success):
            return .success(success)
        case .failure(let error):
            return .failure(transform(error))
        case .canceled:
            return .canceled
        }
    }
    
}
