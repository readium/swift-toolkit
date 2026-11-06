//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Locates a snippet of text in the text content extracted from a PDF page.
///
/// The text extracted by PDFKit contains layout artifacts (line breaks, soft
/// hyphens, ligatures) which rarely survive in a `Locator`'s `text.highlight`.
/// Both sides are normalized before matching, and the matched range is mapped
/// back to offsets valid in the *original* page string, so that it can be fed
/// to `PDFPage.selection(for:)`.
enum PDFTextMatcher {
    /// Finds the range of `query` in `text`, returning UTF-16 offsets valid in
    /// the original (unnormalized) `text`.
    ///
    /// When the query occurs several times, the `before` and `after` context
    /// strings disambiguate the match, falling back to the first occurrence.
    static func findRange(
        of query: String,
        in text: String,
        before: String? = nil,
        after: String? = nil
    ) -> NSRange? {
        let normalizedText = NormalizedString(text)
        let normalizedQuery = NormalizedString(query)

        let matches = normalizedText.occurrences(of: normalizedQuery)
        guard var best = matches.first else {
            return nil
        }

        if matches.count > 1 {
            let beforeUnits = leadingContextUnits(of: before)
            let afterUnits = trailingContextUnits(of: after)
            var bestScore = -1
            for match in matches {
                let score = normalizedText.matchCount(suffixOf: beforeUnits, endingAt: match.lowerBound)
                    + normalizedText.matchCount(prefixOf: afterUnits, startingAt: match.upperBound)
                if score > bestScore {
                    bestScore = score
                    best = match
                }
            }
        }

        return normalizedText.originalRange(of: best)
    }

    /// Normalizes a `text.before` context string, which precedes the match.
    ///
    /// Normalization drops the whitespace adjoining the highlight, but on the
    /// page it collapses to a single space separating the context from the
    /// match; reinstate it so context scoring can cross the word boundary.
    private static func leadingContextUnits(of context: String?) -> [unichar] {
        guard let context = context else {
            return []
        }
        var units = NormalizedString(context).utf16
        if let last = context.unicodeScalars.last, CharacterSet.whitespacesAndNewlines.contains(last) {
            units.append(unichar(32))
        }
        return units
    }

    /// Normalizes a `text.after` context string, which follows the match.
    ///
    /// See `leadingContextUnits(of:)` for the whitespace reinstatement.
    private static func trailingContextUnits(of context: String?) -> [unichar] {
        guard let context = context else {
            return []
        }
        var units = NormalizedString(context).utf16
        if let first = context.unicodeScalars.first, CharacterSet.whitespacesAndNewlines.contains(first) {
            units.insert(unichar(32), at: 0)
        }
        return units
    }
}

/// A string normalized for matching against PDF-extracted text, with a map
/// from each normalized UTF-16 unit back to the UTF-16 range it came from in
/// the original string.
///
/// Normalization: strips soft hyphens, collapses whitespace runs (including
/// newlines) to a single space, and applies per-scalar compatibility
/// decomposition (NFKD) to fold ligatures and make canonically-equivalent
/// inputs comparable.
private struct NormalizedString {
    private(set) var utf16: [unichar] = []
    /// For each normalized UTF-16 unit, the range of UTF-16 offsets of the
    /// original scalar(s) it came from.
    private(set) var map: [Range<Int>] = []

    init(_ string: String) {
        var pendingWhitespace: Range<Int>?
        var offset = 0

        for scalar in string.unicodeScalars {
            let sourceRange = offset ..< (offset + UTF16.width(scalar))
            offset = sourceRange.upperBound

            if scalar == "\u{00AD}" { // soft hyphen
                continue
            }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                pendingWhitespace = (pendingWhitespace?.lowerBound ?? sourceRange.lowerBound) ..< sourceRange.upperBound
                continue
            }
            if let whitespace = pendingWhitespace {
                pendingWhitespace = nil
                // Leading whitespace is dropped instead of collapsed.
                if !utf16.isEmpty {
                    utf16.append(unichar(32))
                    map.append(whitespace)
                }
            }
            for unit in String(scalar).decomposedStringWithCompatibilityMapping.utf16 {
                utf16.append(unit)
                map.append(sourceRange)
            }
        }
        // Trailing whitespace is dropped.
    }

    /// All the ranges of `query` in this string, in normalized offsets.
    func occurrences(of query: NormalizedString) -> [Range<Int>] {
        let queryUnits = query.utf16
        guard !queryUnits.isEmpty, utf16.count >= queryUnits.count else {
            return []
        }
        var result: [Range<Int>] = []
        for start in 0 ... (utf16.count - queryUnits.count) {
            if utf16[start ..< (start + queryUnits.count)].elementsEqual(queryUnits) {
                result.append(start ..< (start + queryUnits.count))
            }
        }
        return result
    }

    /// Maps a range of normalized offsets back to a range of UTF-16 offsets
    /// in the original string.
    func originalRange(of range: Range<Int>) -> NSRange? {
        guard !range.isEmpty, range.upperBound <= map.count else {
            return nil
        }
        let start = map[range.lowerBound].lowerBound
        let end = map[range.upperBound - 1].upperBound
        return NSRange(location: start, length: end - start)
    }

    /// Number of consecutive units at the end of `context` matching the units
    /// right before `index`.
    func matchCount(suffixOf context: [unichar], endingAt index: Int) -> Int {
        var count = 0
        while count < context.count, index - count - 1 >= 0,
              context[context.count - count - 1] == utf16[index - count - 1]
        {
            count += 1
        }
        return count
    }

    /// Number of consecutive units at the start of `context` matching the
    /// units at and after `index`.
    func matchCount(prefixOf context: [unichar], startingAt index: Int) -> Int {
        var count = 0
        while count < context.count, index + count < utf16.count,
              context[count] == utf16[index + count]
        {
            count += 1
        }
        return count
    }
}
