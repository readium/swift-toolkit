//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import NaturalLanguage

/// A tokenizer splitting a String into range tokens (e.g. words, sentences, etc.).
public typealias TextTokenizer = Tokenizer<String, Range<String.Index>>

/// A text token unit which can be used with a `TextTokenizer`.
public enum TextUnit {
    case word, sentence, paragraph
}

public enum TextTokenizerError: Error {
    case rangeConversionFailed(range: NSRange, string: String)
}

/// A default cluster `Tokenizer` taking advantage of the best capabilities of each iOS version.
public func makeDefaultTextTokenizer(unit: TextUnit, language: Language? = nil) -> TextTokenizer {
    if #available(iOS 12.0, *) {
        return makeNLTextTokenizer(unit: unit, language: language)
    } else {
        return makeNSTextTokenizer(unit: unit)
    }
}

// MARK: - NL Text Tokenizer

/// A text `Tokenizer` using iOS 12+'s NaturalLanguage framework.
@available(iOS 12.0, *)
public func makeNLTextTokenizer(unit: TextUnit, language: Language? = nil) -> TextTokenizer {
    let unit = unit.nlUnit
    let language = language.map { NLLanguage($0.code.bcp47) }

    func tokenize(_ text: String) throws -> [Range<String.Index>] {
        let tokenizer = NLTokenizer(unit: unit)
        tokenizer.string = text
        if let language = language {
            tokenizer.setLanguage(language)
        }

        return tokenizer.tokens(for: text.startIndex ..< text.endIndex)
            .map { $0.trimmingWhitespaces(in: text) }
            // Remove empty ranges.
            .filter { $0.upperBound.utf16Offset(in: text) - $0.lowerBound.utf16Offset(in: text) > 0 }
    }

    return tokenize
}

private extension TextUnit {
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

// MARK: - NS Text Tokenizer

/// A text `Tokenizer` using iOS 11+'s `NSLinguisticTaggerUnit`.
///
/// Prefer using NLTokenizer on iOS 12+.
public func makeNSTextTokenizer(
    unit: TextUnit,
    options: NSLinguisticTagger.Options = [.joinNames, .omitPunctuation, .omitWhitespace]
) -> TextTokenizer {
    let unit = unit.nsUnit

    func tokenize(_ text: String) throws -> [Range<String.Index>] {
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
                error = TextTokenizerError.rangeConversionFailed(range: nsRange, string: text)
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

    return tokenize
}

private extension TextUnit {
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

// MARK: - Simple Text Tokenizer

/// A `Tokenizer` using the basic `NSString.enumerateSubstrings()` API.
///
/// Prefer using `NLTokenizer` or `NSTokenizer` on more recent versions of iOS.
public func makeSimpleTextTokenizer(unit: TextUnit) -> TextTokenizer {
    let options = unit.enumerationOptions.union(.substringNotRequired)

    func tokenize(_ text: String) throws -> [Range<String.Index>] {
        var tokens: [Range<String.Index>] = []
        text.enumerateSubstrings(
            in: text.startIndex ..< text.endIndex,
            options: options
        ) { _, range, _, _ in
            tokens.append(range)
        }
        return tokens
            .map { $0.trimmingWhitespaces(in: text) }
            // Remove empty ranges.
            .filter { $0.upperBound.utf16Offset(in: text) - $0.lowerBound.utf16Offset(in: text) > 0 }
    }

    return tokenize
}

private extension TextUnit {
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
