//
//  String.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 30/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

extension String {
    
    /// Returns a copy of the string after adding the given `prefix` if it's not already there.
    public func addingPrefix(_ prefix: String) -> String {
        if hasPrefix(prefix) {
            return self
        } else {
            return prefix + self
        }
    }
    
    /// Returns a copy of the string after removing the given `prefix`, when present.
    public func removingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else {
            return self
        }
        return String(dropFirst(prefix.count))
    }

    /// Replaces the `prefix`, if present, by the given `replacement` prefix.
    public func replacingPrefix(_ prefix: String, by replacement: String) -> String {
        guard hasPrefix(prefix) else {
            return self
        }
        return removingPrefix(prefix).addingPrefix(replacement)
    }

    /// Returns a substring before the last occurrence of `delimiter`.
    /// If the string does not contain the delimiter, returns the original string itself.
    func substringBeforeLast(_ delimiter: String) -> String? {
        guard let range = range(of: delimiter, options: [.backwards, .literal]) else {
            return self
        }
        return String(self[...range.lowerBound])
    }

    /// Formats a `percentage` into a localized String.
    public static func _readium_localizedPercentage(_ percentage: Double) -> String {
        percentageFormatter.string(from: NSNumber(value: percentage))
            ?? String(format: "%.0f%%", percentage)
    }
}

private let percentageFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.minimumIntegerDigits = 1
    formatter.maximumIntegerDigits = 3
    formatter.maximumFractionDigits = 0
    return formatter
}()