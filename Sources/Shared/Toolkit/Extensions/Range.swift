//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension Range where Bound == String.Index {
    /// Trims leading and trailing whitespaces and newlines from this range in the given `string`.
    func trimmingWhitespaces(in string: String) -> Self {
        var onlyWhitespaces = true
        var range = self

        for i in string[range].indices.reversed() {
            let char = string[i]
            if char.isWhitespace || char.isNewline {
                continue
            }
            onlyWhitespaces = false
            range = range.lowerBound ..< string.index(after: i)
            break
        }

        for i in string[range].indices {
            let char = string[i]
            if char.isWhitespace || char.isNewline {
                continue
            }
            onlyWhitespaces = false
            range = i ..< range.upperBound
            break
        }

        guard !onlyWhitespaces else {
            return lowerBound ..< lowerBound
        }

        return range
    }
}
