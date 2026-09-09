//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

package extension String {
    /// Returns a copy of the string after removing the given `prefix`, when present.
    func removingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else {
            return self
        }
        return String(dropFirst(prefix.count))
    }

    /// Returns a copy of the string after adding the given `suffix` if it's not already there.
    func addingSuffix(_ suffix: String) -> String {
        if hasSuffix(suffix) {
            return self
        } else {
            return self + suffix
        }
    }

    /// Returns a copy of the string after removing the given `suffix`, when present.
    func removingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else {
            return self
        }
        return String(dropLast(suffix.count))
    }

    /// Replaces multiple whitespaces by a single space.
    func coalescingWhitespaces() -> String {
        replacingOccurrences(of: "[\\s\n]+", with: " ", options: .regularExpression, range: nil)
    }

    /// Same as `index(_,offsetBy:)` but without crashing when reaching the end of the string.
    func clampedIndex(_ i: String.Index, offsetBy n: Int) -> String.Index {
        precondition(n != 0)
        let limit = (n > 0) ? endIndex : startIndex
        guard let index = index(i, offsetBy: n, limitedBy: limit) else {
            return limit
        }
        return index
    }

    func orNilIfEmpty() -> String? {
        guard !isEmpty else {
            return nil
        }
        return self
    }

    func orNilIfBlank() -> String? {
        isBlank ? nil : self
    }

    /// Returns `true` if the string is empty or contains only whitespace and
    /// newline characters.
    var isBlank: Bool {
        allSatisfy { $0.isWhitespace || $0.isNewline }
    }
}
