//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A tokenizer splitting a `Content` into smaller pieces.
public typealias ContentTokenizer = Tokenizer<Content, Content>

/// A `ContentTokenizer` using the default `TextTokenizer` to split the text of the `Content` by `unit`.
public func makeTextContentTokenizer(unit: TextUnit, language: Language?) -> ContentTokenizer {
    makeTextContentTokenizer(with: makeDefaultTextTokenizer(unit: unit, language: language))
}

/// A `ContentTokenizer` using a `TextTokenizer` to split the text of the `Content`.
public func makeTextContentTokenizer(with tokenizer: @escaping TextTokenizer) -> ContentTokenizer {
    func tokenize(_ span: Content.TextSpan) throws -> [Content.TextSpan] {
        try tokenizer(span.text)
            .map { range in
                Content.TextSpan(
                    locator: span.locator.copy(text: { $0 = extractTextContext(in: span.text, for: range) }),
                    language: span.language,
                    text: String(span.text[range])
                )
            }
    }

    func tokenize(_ content: Content) throws -> [Content] {
        switch content.data {
        case .audio, .image:
            return [content]
        case .text(spans: let spans, style: let style):
            return [Content(
                locator: content.locator,
                data: .text(
                    spans: try spans.flatMap { try tokenize($0) },
                    style: style
                )
            )]
        }
    }

    return tokenize
}

private func extractTextContext(in string: String, for range: Range<String.Index>) -> Locator.Text {
    let after = String(string[range.upperBound..<string.clampedIndex(range.upperBound, offsetBy: 50)])
    let before = String(string[string.clampedIndex(range.lowerBound, offsetBy: -50)..<range.lowerBound])
    return Locator.Text(
        after: Optional(after).takeIf { !$0.isEmpty },
        before: Optional(before).takeIf { !$0.isEmpty },
        highlight: String(string[range])
    )
}
