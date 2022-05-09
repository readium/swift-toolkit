//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public enum NSTokenizerError: Error {
    case rangeConversionFailed(range: NSRange, string: String)
}

/// A text `Tokenizer` using iOS 11+'s `NSLinguisticTaggerUnit`.
///
/// Prefer using NLTokenizer on iOS 12+.
@available(iOS 11.0, *)
public class NSTokenizer: Tokenizer, Loggable {
    private let unit: NSLinguisticTaggerUnit
    private let options: NSLinguisticTagger.Options

    public init(
        unit: TokenUnit,
        options: NSLinguisticTagger.Options = [.joinNames, .omitPunctuation, .omitWhitespace]
    ) {
        self.unit = unit.nsUnit
        self.options = options
    }

    public func tokenize(text: String) throws -> [Range<String.Index>] {
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = text

        var error: Error?
        var tokens: [Range<String.Index>] = []
        tagger.enumerateTags(
            in: NSRange(location: 0, length: text.utf16.count),
            unit: unit,
            scheme: .tokenType,
            options: options
        ) { _, nsRange, _ in
            guard let range = Range<String.Index>(nsRange, in: text) else {
                error = NSTokenizerError.rangeConversionFailed(range: nsRange, string: text)
                return
            }
            tokens.append(range)
        }

        if let error = error {
            throw error
        }

        return tokens
            .map { $0.trimmingWhitespaces(in: text) }
            // Remove empty ranges.
            .filter { $0.upperBound.utf16Offset(in: text) - $0.lowerBound.utf16Offset(in: text) > 0 }
    }
}

private extension TokenUnit {
    @available(iOS 11.0, *)
    var nsUnit: NSLinguisticTaggerUnit {
        switch self {
        case .word:
            return .word
        case .sentence:
            return .sentence
        case .paragraph:
            return .paragraph
        }
    }
}
