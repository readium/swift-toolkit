//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import NaturalLanguage

/// A text `Tokenizer` using iOS 12+'s NaturalLanguage framework.
@available(iOS 12.0, *)
public class NLTokenizer: Tokenizer {
    private let unit: NLTokenUnit
    private let language: NLLanguage?

    public init(unit: TokenUnit, language: String? = nil) {
        self.unit = unit.nlUnit
        self.language = language.map { NLLanguage($0) }
    }

    public func tokenize(text: String) throws -> [Range<String.Index>] {
        let tokenizer = NaturalLanguage.NLTokenizer(unit: unit)
        tokenizer.string = text
        if let language = language {
            tokenizer.setLanguage(language)
        }

        return tokenizer.tokens(for: text.startIndex..<text.endIndex)
            .map { $0.trimmingWhitespaces(in: text) }
            // Remove empty ranges.
            .filter { $0.upperBound.utf16Offset(in: text) - $0.lowerBound.utf16Offset(in: text) > 0 }
    }
}

private extension TokenUnit {
    @available(iOS 12.0, *)
    var nlUnit: NLTokenUnit {
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