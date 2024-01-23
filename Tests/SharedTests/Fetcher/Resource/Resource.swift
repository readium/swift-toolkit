//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import R2Shared

extension ResourceError: Equatable {
    public static func == (lhs: ResourceError, rhs: ResourceError) -> Bool {
        switch (lhs, rhs) {
        case (.notFound, .notFound),
             (.forbidden, .forbidden),
             (.unavailable, .unavailable):
            return true
        case let (.other(lerr), .other(rerr)) where lerr.localizedDescription == rerr.localizedDescription:
            return true
        default:
            return false
        }
    }
}
