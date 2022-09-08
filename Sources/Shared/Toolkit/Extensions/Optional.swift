//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension Optional {
    
    /// Unwraps the optional or throws the given `error`.
    public func orThrow(_ error: @autoclosure () -> Error) throws -> Wrapped {
        switch self {
        case .some(let value):
            return value
        case .none:
            throw error()
        }
    }

    /// Returns `nil` if the value doesn't pass the given `condition`.
    public func takeIf(_ condition: (Wrapped) -> Bool) -> Self {
        guard
            case .some(let value) = self,
            condition(value)
        else {
            return nil
        }
        return value
    }

    /// Returns the wrapped value and modify the variable to be nil.
    mutating func pop() -> Wrapped? {
        let res = self
        self = nil
        return res
    }
}
