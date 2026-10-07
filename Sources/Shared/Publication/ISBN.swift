//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An International Standard Book Number, as an ISBN-10 or an ISBN-13.
package struct ISBN: RawRepresentable, Hashable, Sendable {
    /// The ISBN without separators, such as `9780306406157` or `080442957X`.
    package let rawValue: String

    /// URN of this ISBN, such as `urn:isbn:9780306406157`.
    package var urn: String {
        "urn:isbn:\(rawValue)"
    }

    /// Creates an ISBN from its text form, ignoring its spaces and hyphens.
    ///
    /// Returns `nil` when `rawValue` is not a valid ISBN-10 or ISBN-13,
    /// including its check digit. An ISBN-10 is not converted to an ISBN-13.
    package init?(rawValue: String) {
        let string = rawValue.filter { !$0.isWhitespace && $0 != "-" }.uppercased()

        // `X` stands for 10 in the check digit of an ISBN-10.
        let values = string.compactMap { character -> Int? in
            character == "X" ? 10 : (character.isASCII ? character.wholeNumberValue : nil)
        }
        guard values.count == string.count else {
            return nil
        }

        let isValid: Bool
        switch values.count {
        case 10:
            let sum = zip(values, stride(from: 10, to: 0, by: -1)).reduce(0) { $0 + $1.0 * $1.1 }
            isValid = !values.dropLast().contains(10) && sum.isMultiple(of: 11)
        case 13:
            let sum = values.enumerated().reduce(0) { $0 + $1.element * ($1.offset.isMultiple(of: 2) ? 1 : 3) }
            isValid = !values.contains(10) && sum.isMultiple(of: 10)
        default:
            isValid = false
        }

        guard isValid else {
            return nil
        }
        self.rawValue = string
    }
}
