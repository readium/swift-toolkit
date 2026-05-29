//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A type-erased wrapper for a value that is both `Hashable` and `Sendable`.
package struct AnySendableHashable: Hashable, Sendable {
    package let base: any Hashable & Sendable
    private let equals: @Sendable (any Hashable & Sendable) -> Bool
    private let hasher: @Sendable (inout Hasher) -> Void

    package var asAnyHashable: AnyHashable {
        AnyHashable(base)
    }

    package init<T: Hashable & Sendable>(_ base: T) {
        if let nested = base as? AnySendableHashable {
            self.base = nested.base
            equals = nested.equals
            hasher = nested.hasher
        } else {
            self.base = base
            equals = { ($0 as? T) == base }
            hasher = { base.hash(into: &$0) }
        }
    }

    package static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.equals(rhs.base)
    }

    package func hash(into hasher: inout Hasher) {
        self.hasher(&hasher)
    }

    /// Safely unwraps the underlying value to the expected type.
    package func unwrap<T: Hashable & Sendable>(as type: T.Type = T.self) -> T? {
        base as? T
    }
}
