//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension Double {

    /// Formats the number with the given number of `maximumFractionDigits`.
    ///
    /// If `percent` is true, the number is multiplied by 100 and the percent
    /// sign is appended.
    public func format(maximumFractionDigits: Int, percent: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = percent ? .percent : .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        if percent {
            formatter.minimumIntegerDigits = 1
            formatter.maximumIntegerDigits = 3
        }

        guard let string = formatter.string(from: NSNumber(value: self)) else {
            var number = self
            if percent {
                number *= 100
            }
            var string = String(format: "%.\(maximumFractionDigits)f", number)
            if percent {
                string += "%"
            }
            return string
        }
        return string
    }
}
