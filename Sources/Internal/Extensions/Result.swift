//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Result {
    /// Asynchronous variant of `map`.
    @inlinable func map<NewSuccess>(
        _ transform: (Success) async -> NewSuccess
    ) async -> Result<NewSuccess, Failure> {
        switch self {
        case let .success(success):
            return await .success(transform(success))
        case let .failure(error):
            return .failure(error)
        }
    }

    /// Asynchronous variant of `flatMap`.
    @inlinable func flatMap<NewSuccess>(
        _ transform: (Success) async -> Result<NewSuccess, Failure>
    ) async -> Result<NewSuccess, Failure> {
        switch self {
        case let .success(success):
            return await transform(success)
        case let .failure(error):
            return .failure(error)
        }
    }

    @inlinable func recover(
        _ catching: (Failure) async -> Self
    ) async -> Self {
        switch self {
        case let .success(success):
            return .success(success)
        case let .failure(error):
            return await catching(error)
        }
    }
}
