//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension ClosedRange where Bound == Double {

    /// Returns the equivalent percentage from 0.0 to 1.0 for the given `value` in the range.
    func percentageForValue(_ value: Bound) -> Double {
        (value - lowerBound) / (upperBound - lowerBound)
    }

    /// Returns the actual value in the range for the given `percentage` from 0.0 to 1.0.
    func valueForPercentage(_ percentage: Double) -> Bound {
        ((upperBound - lowerBound) * percentage) + lowerBound
    }
}
