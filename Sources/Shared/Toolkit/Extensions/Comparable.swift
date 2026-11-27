//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

package extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

package extension Comparable where Self: AdditiveArithmetic {
    /// Returns the value, or `nil` if it is not above zero (NaN included).
    var positiveOrNil: Self? {
        self > .zero ? self : nil
    }

    /// Returns the value, or `nil` if it is below zero (NaN included).
    var nonNegativeOrNil: Self? {
        self >= .zero ? self : nil
    }
}
