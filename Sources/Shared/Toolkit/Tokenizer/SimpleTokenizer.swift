//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A `Tokenizer` using the basic `NSString.enumerateSubstrings()` API.
///
/// Prefer using `NLTokenizer` or `NSTokenizer` on more recent versions of iOS.
public class SimpleTokenizer: Tokenizer {
    private let options: NSString.EnumerationOptions

    public init(unit: TokenUnit) {
        self.options = unit.enumerationOptions.union(.substringNotRequired)
    }

    public func tokenize(text: String) throws -> [Range<String.Index>] {
        var tokens: [Range<String.Index>] = []
        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: options
        ) { _, range, _, _ in
            tokens.append(range)
        }
        return tokens
            .map { $0.trimmingWhitespaces(in: text) }
            // Remove empty ranges.
            .filter { $0.upperBound.utf16Offset(in: text) - $0.lowerBound.utf16Offset(in: text) > 0 }
    }
}

private extension TokenUnit {
    var enumerationOptions: NSString.EnumerationOptions {
        switch self {
        case .word:
            return .byWords
        case .sentence:
            return .bySentences
        case .paragraph:
            return .byParagraphs
        }
    }
}