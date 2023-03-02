//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension Double {

    public var percentageString: String {
        formatPercentage()
    }

    /// Formats as a percentage.
    public func formatPercentage(maximumFractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumIntegerDigits = 1
        formatter.maximumIntegerDigits = 3
        formatter.maximumFractionDigits = maximumFractionDigits

        guard let string = formatter.string(from: NSNumber(value: self)) else {
            return String(format: "%.\(maximumFractionDigits)f%%", self * 100)
        }
        return string
    }

    /// Formats as a decimal number.
    public func formatDecimal(maximumFractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits

        guard let string = formatter.string(from: NSNumber(value: self)) else {
            return String(format: "%.\(maximumFractionDigits)f", self)
        }
        return string
    }
}
