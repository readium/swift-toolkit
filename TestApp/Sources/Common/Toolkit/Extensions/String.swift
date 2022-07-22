//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension String {
    
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

    /// Formats a `percentage` into a localized String.
    static func localizedPercentage(_ percentage: Double) -> String {
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
