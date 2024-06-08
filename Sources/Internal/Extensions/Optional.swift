//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Optional {

    /// Asynchronous variant of `map`.
    @inlinable func map<U>(_ transform: (Wrapped) async throws -> U) async rethrows -> U? {
        switch self {
        case .some(let wrapped):
            return .some(try await transform(wrapped))
        case .none:
            return .none
        }
    }

    /// Asynchronous variant of `flatMap`.
    @inlinable func flatMap<U>(_ transform: (Wrapped) async throws -> U?) async rethrows -> U? {
        switch self {
        case .some(let wrapped):
            return try await transform(wrapped)
        case .none:
            return .none
        }
    }
}
