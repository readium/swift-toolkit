//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A tokenizer splits a String into tokens (e.g. words, sentences, etc.).
public protocol Tokenizer {

    /// Splits the given `text` into tokens and return their range in the string.
    func tokenize(text: String) throws -> [Range<String.Index>]
}

/// A text token unit which can be used with a `Tokenizer`.
public enum TokenUnit {
    case word, sentence, paragraph
}

/// A default cluster `Tokenizer` taking advantage of the best capabilities of each iOS version.
public class DefaultTokenizer: Tokenizer {
    private let tokenizer: Tokenizer

    public init(unit: TokenUnit, language: String? = nil) {
        if #available(iOS 12.0, *) {
            tokenizer = NLTokenizer(unit: unit, language: language)
        } else if #available(iOS 11.0, *) {
            tokenizer = NSTokenizer(unit: unit)
        } else {
            tokenizer = SimpleTokenizer(unit: unit)
        }
    }

    public func tokenize(text: String) throws -> [Range<String.Index>] {
        try tokenizer.tokenize(text: text)
    }
}