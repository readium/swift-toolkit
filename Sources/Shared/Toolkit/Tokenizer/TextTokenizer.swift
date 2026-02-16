//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import NaturalLanguage

/// A tokenizer splitting a String into range tokens (e.g. words, sentences, etc.).
public typealias TextTokenizer = Tokenizer<String, Range<String.Index>>

/// A text token unit which can be used with a `TextTokenizer`.
public enum TextUnit: Sendable {
    case word, sentence, paragraph
}

/// A default text `Tokenizer` using the NaturalLanguage framework.
public func makeDefaultTextTokenizer(unit: TextUnit, language: Language? = nil) -> TextTokenizer {
    makeNLTextTokenizer(unit: unit, language: language)
}

// MARK: - NL Text Tokenizer

/// A text `Tokenizer` using the NaturalLanguage framework.
public func makeNLTextTokenizer(unit: TextUnit, language: Language? = nil) -> TextTokenizer {
    let nlUnit = unit.nlUnit
    let nlLanguage = language.map { NLLanguage($0.code.bcp47) }

    return { @Sendable text in
        let tokenizer = NLTokenizer(unit: nlUnit)
        tokenizer.string = text
        if let nlLanguage = nlLanguage {
            tokenizer.setLanguage(nlLanguage)
        }

        return tokenizer.tokens(for: text.startIndex ..< text.endIndex)
            .map { $0.trimmingWhitespaces(in: text) }
            // Remove empty ranges.
            .filter { $0.upperBound.utf16Offset(in: text) - $0.lowerBound.utf16Offset(in: text) > 0 }
    }
}

private extension TextUnit {
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

