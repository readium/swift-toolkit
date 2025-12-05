//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public enum Either<L, R> {
    case left(L)
    case right(R)
}

extension Either: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .left(l):
            return "Either.left(\(l))"
        case let .right(r):
            return "Either.right(\(r))"
        }
    }
}
