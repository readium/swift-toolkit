//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A tokenizer splitting a `ContentElement` into smaller pieces.
public typealias ContentTokenizer = Tokenizer<ContentElement, ContentElement>

/// A `ContentTokenizer` using a `TextTokenizer` to split the text of the `Content`.
///
/// - Parameter contextSnippetLength: Length of `before` and `after` snippets in the produced `Locator`s.
public func makeTextContentTokenizer(
    defaultLanguage: Language?,
    contextSnippetLength: Int = 50,
    textTokenizerFactory: @escaping (Language?) -> TextTokenizer
) -> ContentTokenizer {
    func tokenize(segment: TextContentElement.Segment) throws -> [TextContentElement.Segment] {
        let tokenize = textTokenizerFactory(segment.language ?? defaultLanguage)

        return try tokenize(segment.text)
            .map { range in
                var segment = segment
                segment.locator = segment.locator.copy(text: {
                    $0 = extractTextContext(
                        in: segment.text,
                        for: range,
                        contextSnippetLength: contextSnippetLength
                    )
                })
                segment.text = String(segment.text[range])
                return segment
            }
    }

    func tokenize(_ content: ContentElement) throws -> [ContentElement] {
        if var content = content as? TextContentElement {
            content.segments = try content.segments.flatMap(tokenize(segment:))
            return [content]
        } else {
            return [content]
        }
    }

    return tokenize
}

private func extractTextContext(in string: String, for range: Range<String.Index>, contextSnippetLength: Int) -> Locator.Text {
    let after = String(string[range.upperBound ..< string.clampedIndex(range.upperBound, offsetBy: contextSnippetLength)])
    let before = String(string[string.clampedIndex(range.lowerBound, offsetBy: -contextSnippetLength) ..< range.lowerBound])
    return Locator.Text(
        after: Optional(after).takeIf { !$0.isEmpty },
        before: Optional(before).takeIf { !$0.isEmpty },
        highlight: String(string[range])
    )
}
