//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit
import ReadiumShared

/// Resolves PDF anchor data back to coordinate bounds for rendering highlights.
///
/// Uses a priority-based resolution strategy:
/// 1. Quads (pixel-perfect) - directly use stored coordinates
/// 2. Character range (precise) - create selection from stored offsets
/// 3. Context-aware text search (fallback) - find text with surrounding context
public struct PDFAnchorResolver: Loggable {

    /// Resolves anchor data from a locator to renderable bounds.
    ///
    /// - Parameters:
    ///   - locator: The locator containing anchor data in otherLocations.
    ///   - page: The PDF page to resolve bounds on.
    /// - Returns: Array of CGRect bounds for each line, or empty if resolution fails.
    public static func resolveBounds(
        from locator: Locator,
        on page: PDFPage
    ) -> [CGRect] {
        // Try to extract anchor from otherLocations
        guard let anchorData = locator.locations.otherLocations["pdfAnchor"] else {
            // No anchor data - fall back to legacy text search
            return legacyTextSearch(locator: locator, page: page)
        }

        // Parse anchor data
        guard let anchor = parseAnchor(anchorData) else {
            log(.warning, "Failed to parse PDF anchor data")
            return legacyTextSearch(locator: locator, page: page)
        }

        // Strategy 1: Try quads first (pixel-perfect)
        if let bounds = resolveFromQuads(anchor.quads) {
            log(.debug, "Resolved PDF highlight from quads")
            return bounds
        }

        // Strategy 2: Try character range (precise)
        if let bounds = resolveFromCharacterRange(anchor, page: page) {
            log(.debug, "Resolved PDF highlight from character range")
            return bounds
        }

        // Strategy 3: Context-aware text search (fallback)
        if let bounds = resolveFromContextSearch(anchor, page: page) {
            log(.debug, "Resolved PDF highlight from context search")
            return bounds
        }

        log(.warning, "All PDF anchor resolution strategies failed")
        return []
    }

    // MARK: - Resolution Methods (internal for testing)

    /// Parses anchor data from dictionary or JSON string format.
    /// - Note: Internal for testing.
    static func parseAnchor(_ data: Any) -> ParsedAnchor? {
        // Handle both dictionary and JSON string formats
        let dict: [String: Any]
        if let d = data as? [String: Any] {
            dict = d
        } else if let jsonString = data as? String,
                  let jsonData = jsonString.data(using: .utf8),
                  let d = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            dict = d
        } else {
            return nil
        }

        guard let text = dict["text"] as? String else {
            return nil
        }

        return ParsedAnchor(
            pageIndex: dict["pageIndex"] as? Int,
            quads: parseQuads(dict["quads"]),
            characterStart: dict["characterStart"] as? Int,
            characterEnd: dict["characterEnd"] as? Int,
            text: text,
            textBefore: dict["textBefore"] as? String,
            textAfter: dict["textAfter"] as? String
        )
    }

    /// Parses quad coordinate data.
    /// - Note: Internal for testing.
    static func parseQuads(_ data: Any?) -> [[CGPoint]]? {
        guard let quadsArray = data as? [[[String: Double]]] else {
            return nil
        }

        return quadsArray.compactMap { quad -> [CGPoint]? in
            guard quad.count == 4 else { return nil }

            let points = quad.compactMap { point -> CGPoint? in
                guard let x = point["x"], let y = point["y"] else { return nil }
                return CGPoint(x: x, y: y)
            }

            // Require exactly 4 valid points
            guard points.count == 4 else { return nil }
            return points
        }
    }

    /// Resolves bounds from quad coordinates.
    /// - Note: Internal for testing.
    static func resolveFromQuads(_ quads: [[CGPoint]]?) -> [CGRect]? {
        guard let quads = quads, !quads.isEmpty else {
            return nil
        }

        let bounds = quads.compactMap { quad -> CGRect? in
            guard quad.count == 4 else { return nil }

            // Convert quad points to bounding rect
            let minX = quad.map(\.x).min() ?? 0
            let maxX = quad.map(\.x).max() ?? 0
            let minY = quad.map(\.y).min() ?? 0
            let maxY = quad.map(\.y).max() ?? 0

            let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            guard !rect.isEmpty else { return nil }
            return rect
        }

        // Return nil if no valid bounds were produced
        guard !bounds.isEmpty else { return nil }
        return bounds
    }

    private static func resolveFromCharacterRange(
        _ anchor: ParsedAnchor,
        page: PDFPage
    ) -> [CGRect]? {
        guard let start = anchor.characterStart,
              let end = anchor.characterEnd,
              start < end
        else {
            return nil
        }

        let nsRange = NSRange(location: start, length: end - start)
        guard let selection = page.selection(for: nsRange) else {
            return nil
        }

        return boundsFromSelection(selection, page: page)
    }

    private static func resolveFromContextSearch(
        _ anchor: ParsedAnchor,
        page: PDFPage
    ) -> [CGRect]? {
        guard let pageText = page.string else {
            return nil
        }

        // Find all occurrences of the text
        var ranges: [Range<String.Index>] = []
        var searchStart = pageText.startIndex

        while let range = pageText.range(of: anchor.text, range: searchStart..<pageText.endIndex) {
            ranges.append(range)
            searchStart = range.upperBound
        }

        guard !ranges.isEmpty else {
            // Try case-insensitive as last resort
            if let range = pageText.range(of: anchor.text, options: .caseInsensitive) {
                let nsRange = NSRange(range, in: pageText)
                if let selection = page.selection(for: nsRange) {
                    return boundsFromSelection(selection, page: page)
                }
            }
            return nil
        }

        // If only one occurrence, use it
        if ranges.count == 1 {
            let nsRange = NSRange(ranges[0], in: pageText)
            if let selection = page.selection(for: nsRange) {
                return boundsFromSelection(selection, page: page)
            }
            return nil
        }

        // Multiple occurrences: score by context match
        let bestRange = ranges.max { range1, range2 in
            contextScore(for: range1, textBefore: anchor.textBefore, textAfter: anchor.textAfter, in: pageText) <
            contextScore(for: range2, textBefore: anchor.textBefore, textAfter: anchor.textAfter, in: pageText)
        }

        guard let best = bestRange else { return nil }

        let nsRange = NSRange(best, in: pageText)
        guard let selection = page.selection(for: nsRange) else {
            return nil
        }

        return boundsFromSelection(selection, page: page)
    }

    /// Calculates a score for how well a range matches the expected context.
    /// - Note: Internal for testing.
    static func contextScore(
        for range: Range<String.Index>,
        textBefore: String?,
        textAfter: String?,
        in text: String
    ) -> Int {
        var score = 0

        if let before = textBefore {
            let contextLength = before.count
            let contextStart = text.index(
                range.lowerBound,
                offsetBy: -contextLength,
                limitedBy: text.startIndex
            ) ?? text.startIndex
            let actualBefore = String(text[contextStart..<range.lowerBound])

            if actualBefore == before {
                score += 20  // Exact match
            } else if actualBefore.hasSuffix(before) {
                score += 15
            } else if actualBefore.lowercased().hasSuffix(before.lowercased()) {
                score += 10
            }
        }

        if let after = textAfter {
            let contextLength = after.count
            let contextEnd = text.index(
                range.upperBound,
                offsetBy: contextLength,
                limitedBy: text.endIndex
            ) ?? text.endIndex
            let actualAfter = String(text[range.upperBound..<contextEnd])

            if actualAfter == after {
                score += 20  // Exact match
            } else if actualAfter.hasPrefix(after) {
                score += 15
            } else if actualAfter.lowercased().hasPrefix(after.lowercased()) {
                score += 10
            }
        }

        return score
    }

    private static func boundsFromSelection(
        _ selection: PDFSelection,
        page: PDFPage
    ) -> [CGRect] {
        let lineSelections = selection.selectionsByLine()

        var bounds: [CGRect] = []
        for lineSelection in lineSelections {
            let lineBounds = lineSelection.bounds(for: page)
            guard !lineBounds.isNull, !lineBounds.isEmpty else { continue }
            bounds.append(lineBounds)
        }

        // Fallback to full selection bounds
        if bounds.isEmpty {
            let fullBounds = selection.bounds(for: page)
            if !fullBounds.isNull, !fullBounds.isEmpty {
                bounds.append(fullBounds)
            }
        }

        return bounds
    }

    private static func legacyTextSearch(locator: Locator, page: PDFPage) -> [CGRect] {
        guard let highlightedText = locator.text.highlight,
              !highlightedText.isEmpty
        else {
            return []
        }

        guard let pageText = page.string else {
            return []
        }

        // Strategy 1: Try exact match first
        if let range = pageText.range(of: highlightedText, options: .caseInsensitive) {
            let nsRange = NSRange(range, in: pageText)
            if let selection = page.selection(for: nsRange) {
                return boundsFromSelection(selection, page: page)
            }
        }

        // Strategy 2: Normalize whitespace and try again
        // TTS may combine text with spaces while PDF has newlines
        let normalizedSearch = normalizeWhitespace(highlightedText)
        let normalizedPage = normalizeWhitespace(pageText)

        if let normalizedRange = normalizedPage.range(of: normalizedSearch, options: .caseInsensitive) {
            // Map back to original page text range
            // Count characters up to the match in normalized text
            let normalizedPrefix = String(normalizedPage[..<normalizedRange.lowerBound])
            let matchLength = normalizedPage.distance(from: normalizedRange.lowerBound, to: normalizedRange.upperBound)

            // Find corresponding position in original text
            if let originalRange = findOriginalRange(in: pageText, normalizedPrefix: normalizedPrefix, matchLength: matchLength) {
                let nsRange = NSRange(originalRange, in: pageText)
                if let selection = page.selection(for: nsRange) {
                    return boundsFromSelection(selection, page: page)
                }
            }
        }

        // Strategy 3: Try matching just the first sentence or first N words
        // This helps when TTS includes extra content
        let firstWords = extractFirstWords(from: highlightedText, count: 5)
        if firstWords.count >= 3, let range = pageText.range(of: firstWords, options: .caseInsensitive) {
            let nsRange = NSRange(range, in: pageText)
            if let selection = page.selection(for: nsRange) {
                return boundsFromSelection(selection, page: page)
            }
        }

        return []
    }

    /// Normalizes whitespace by collapsing multiple spaces/newlines into single spaces.
    /// - Note: Internal for testing.
    static func normalizeWhitespace(_ text: String) -> String {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Extracts the first N words from text.
    /// - Note: Internal for testing.
    static func extractFirstWords(from text: String, count: Int) -> String {
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        let firstWords = words.prefix(count)
        return firstWords.joined(separator: " ")
    }

    /// Maps a position from normalized text back to original text
    private static func findOriginalRange(
        in originalText: String,
        normalizedPrefix: String,
        matchLength: Int
    ) -> Range<String.Index>? {
        // Early return for degenerate cases
        guard matchLength > 0, !originalText.isEmpty else {
            return nil
        }

        // Walk through original text, tracking position in normalized space
        var normalizedPosition = 0
        var originalStart: String.Index?
        var originalEnd: String.Index?
        var inWhitespace = false
        var i = originalText.startIndex

        let targetStart = normalizedPrefix.count
        let targetEnd = targetStart + matchLength

        while i < originalText.endIndex {
            let char = originalText[i]
            let isWhitespace = char.isWhitespace || char.isNewline

            if isWhitespace {
                if !inWhitespace {
                    normalizedPosition += 1  // Count whitespace run as single space
                    inWhitespace = true
                }
            } else {
                normalizedPosition += 1
                inWhitespace = false
            }

            if originalStart == nil && normalizedPosition > targetStart {
                originalStart = i
            }

            if originalStart != nil && normalizedPosition >= targetEnd {
                originalEnd = originalText.index(after: i)
                break
            }

            i = originalText.index(after: i)
        }

        guard let start = originalStart, let end = originalEnd else {
            return nil
        }

        return start..<end
    }

    // MARK: - Internal Types

    /// Parsed anchor data structure.
    /// - Note: Internal for testing.
    struct ParsedAnchor {
        let pageIndex: Int?
        let quads: [[CGPoint]]?
        let characterStart: Int?
        let characterEnd: Int?
        let text: String
        let textBefore: String?
        let textAfter: String?
    }
}
