//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

internal extension UInt64 {

    func ceilMultiple(of divisor: UInt64) -> UInt64 {
        divisor * (self / divisor + ((self % divisor == 0) ? 0 : 1))
    }

    func floorMultiple(of divisor: UInt64) -> UInt64 {
        divisor * (self / divisor)
    }

}

internal extension Range where Bound == UInt64 {

    func contains(_ other: Self) -> Bool {
        lowerBound <= other.lowerBound && upperBound >= other.upperBound
    }

}
