//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Implements the actual search algorithm in sanitized text content.
public protocol StringSearchAlgorithm {
    /// Default value for the search options available with this algorithm.
    ///
    /// If an option does not have a value, it is not supported by the algorithm.
    var options: SearchOptions { get }

    /// Finds all the ranges of occurrences of the given `query` in the `text`.
    func findRanges(
        of query: String,
        options: SearchOptions,
        in text: String,
        language: Language?
    ) async -> [Range<String.Index>]
}

/// A basic `StringSearchAlgorithm` using the native `String.range(of:)` APIs.
public class BasicStringSearchAlgorithm: StringSearchAlgorithm {
    public let options: SearchOptions = .init(
        caseSensitive: false,
        diacriticSensitive: false,
        exact: false,
        regularExpression: false
    )

    public init() {}

    public func findRanges(
        of query: String,
        options: SearchOptions,
        in text: String,
        language: Language?
    ) async -> [Range<String.Index>] {
        var compareOptions: NSString.CompareOptions = []
        if options.regularExpression ?? false {
            compareOptions.insert(.regularExpression)
        } else if options.exact ?? false {
            compareOptions.insert(.literal)
        } else {
            if !(options.caseSensitive ?? false) {
                compareOptions.insert(.caseInsensitive)
            }
            if !(options.diacriticSensitive ?? false) {
                compareOptions.insert(.diacriticInsensitive)
            }
        }

        var ranges: [Range<String.Index>] = []
        var index = text.startIndex
        while
            !Task.isCancelled,
            index < text.endIndex,
            let range = text.range(of: query, options: compareOptions, range: index ..< text.endIndex, locale: language?.locale),
            !range.isEmpty
        {
            ranges.append(range)
            index = text.index(range.lowerBound, offsetBy: 1)
        }

        return ranges
    }
}
