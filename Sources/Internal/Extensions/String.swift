//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension String {
    /// Returns this string after removing any character forbidden in a single path component.
    var sanitizedPathComponent: String {
        // See https://superuser.com/a/358861
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
            .union(.newlines)
            .union(.illegalCharacters)
            .union(.controlCharacters)

        return components(separatedBy: invalidCharacters)
            .joined(separator: " ")
    }

    /// Returns a copy of the string after adding the given `prefix` if it's not already there.
    func addingPrefix(_ prefix: String) -> String {
        if hasPrefix(prefix) {
            return self
        } else {
            return prefix + self
        }
    }

    /// Returns a copy of the string after removing the given `prefix`, when present.
    func removingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else {
            return self
        }
        return String(dropFirst(prefix.count))
    }

    /// Replaces the `prefix`, if present, by the given `replacement` prefix.
    func replacingPrefix(_ prefix: String, by replacement: String) -> String {
        guard hasPrefix(prefix) else {
            return self
        }
        return removingPrefix(prefix).addingPrefix(replacement)
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

    /// Returns a substring before the last occurrence of `delimiter`.
    /// If the string does not contain the delimiter, returns the original string itself.
    func substringBeforeLast(_ delimiter: String) -> String? {
        guard let range = range(of: delimiter, options: [.backwards, .literal]) else {
            return self
        }
        return String(self[..<range.lowerBound])
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
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
