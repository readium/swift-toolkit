//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

package extension Optional {
    /// Unwraps the optional or throws the given `error`.
    func orThrow(_ error: @autoclosure () -> Error) throws -> Wrapped {
        switch self {
        case let .some(value):
            return value
        case .none:
            throw error()
        }
    }

    /// Returns `nil` if the value doesn't pass the given `condition`.
    func takeIf(_ condition: (Wrapped) -> Bool) -> Self {
        guard
            case let .some(value) = self,
            condition(value)
        else {
            return nil
        }
        return value
    }

    /// Asynchronous variant of `map`.
    @inlinable func asyncMap<U>(_ transform: (Wrapped) async throws -> U) async rethrows -> U? {
        switch self {
        case let .some(wrapped):
            return try await .some(transform(wrapped))
        case .none:
            return .none
        }
    }

    /// Asynchronous variant of `flatMap`.
    @inlinable func asyncFlatMap<U>(_ transform: (Wrapped) async throws -> U?) async rethrows -> U? {
        switch self {
        case let .some(wrapped):
            return try await transform(wrapped)
        case .none:
            return .none
        }
    }
}
