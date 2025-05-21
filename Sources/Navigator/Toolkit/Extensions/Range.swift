//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension ClosedRange {
    func clamp(_ value: Bound) -> Bound {
        Swift.min(Swift.max(lowerBound, value), upperBound)
    }
}

extension ClosedRange where Bound == Double {
    /// Returns the equivalent percentage from 0.0 to 1.0 for the given `value` in the range.
    func percentageForValue(_ value: Bound) -> Double {
        (clamp(value) - lowerBound) / (upperBound - lowerBound)
    }

    /// Returns the actual value in the range for the given `percentage` from 0.0 to 1.0.
    func valueForPercentage(_ percentage: Double) -> Bound {
        ((upperBound - lowerBound) * (0.0 ... 1.0).clamp(percentage)) + lowerBound
    }
}
