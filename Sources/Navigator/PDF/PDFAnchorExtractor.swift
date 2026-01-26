//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit
import ReadiumShared

/// Extracts precise anchor data from a PDF selection for highlight persistence.
///
/// The extractor captures multiple forms of positioning data:
/// - Coordinate quads for pixel-perfect rendering
/// - Character ranges for text-based lookup
/// - Surrounding text context for disambiguation
public struct PDFAnchorExtractor: Loggable {

    /// Number of characters to capture before/after the selection for context.
    public static let contextCharacterCount = 20

    /// Extracts anchor data from a PDF selection.
    ///
    /// - Parameters:
    ///   - selection: The PDF selection to extract anchor data from.
    ///   - page: The page containing the selection.
    /// - Returns: A dictionary suitable for storage in Locator.Locations.otherLocations,
    ///            or nil if extraction fails.
    public static func extractAnchor(
        from selection: PDFSelection,
        on page: PDFPage
    ) -> [String: Any]? {
        guard let pageIndex = page.document?.index(for: page),
              let selectedText = selection.string,
              !selectedText.isEmpty
        else {
            log(.debug, "PDF anchor extraction skipped: invalid selection")
            return nil
        }

        var anchor: [String: Any] = [
            "pageIndex": pageIndex,
            "text": selectedText
        ]

        // Extract coordinate quads
        if let quads = extractQuads(from: selection, on: page) {
            anchor["quads"] = quads
        }

        // Extract character range
        if let pageText = page.string,
           let range = extractCharacterRange(for: selectedText, in: pageText, selection: selection, page: page) {
            anchor["characterStart"] = range.lowerBound
            anchor["characterEnd"] = range.upperBound

            // Extract context
            let (before, after) = extractContext(
                around: range,
                in: pageText,
                contextLength: contextCharacterCount
            )
            if let before = before {
                anchor["textBefore"] = before
            }
            if let after = after {
                anchor["textAfter"] = after
            }
        }

        log(.debug, "PDF anchor extracted: page=\(pageIndex), chars=\(anchor["characterStart"] ?? "nil")-\(anchor["characterEnd"] ?? "nil"), quads=\(anchor["quads"] != nil)")

        return anchor
    }

    /// Extracts quadrilateral bounds for each line of the selection.
    private static func extractQuads(
        from selection: PDFSelection,
        on page: PDFPage
    ) -> [[[String: Double]]]? {
        let lineSelections = selection.selectionsByLine()
        guard !lineSelections.isEmpty else { return nil }

        var quads: [[[String: Double]]] = []

        for lineSelection in lineSelections {
            let bounds = lineSelection.bounds(for: page)
            guard !bounds.isNull, !bounds.isEmpty else { continue }

            // Convert CGRect to quad (4 corner points)
            let quad: [[String: Double]] = [
                ["x": Double(bounds.minX), "y": Double(bounds.minY)],  // bottomLeft
                ["x": Double(bounds.maxX), "y": Double(bounds.minY)],  // bottomRight
                ["x": Double(bounds.maxX), "y": Double(bounds.maxY)],  // topRight
                ["x": Double(bounds.minX), "y": Double(bounds.maxY)]   // topLeft
            ]
            quads.append(quad)
        }

        return quads.isEmpty ? nil : quads
    }

    /// Extracts the character range of the selection within the page text.
    private static func extractCharacterRange(
        for selectedText: String,
        in pageText: String,
        selection: PDFSelection,
        page: PDFPage
    ) -> Range<Int>? {
        // Try to get the range from PDFKit's selection
        // PDFSelection doesn't expose character range directly, so we search

        // Find all occurrences of the selected text
        var ranges: [Range<String.Index>] = []
        var searchStart = pageText.startIndex

        while let range = pageText.range(of: selectedText, range: searchStart..<pageText.endIndex) {
            ranges.append(range)
            searchStart = range.upperBound
        }

        guard !ranges.isEmpty else { return nil }

        // If only one occurrence, use it
        if ranges.count == 1 {
            let range = ranges[0]
            let start = pageText.distance(from: pageText.startIndex, to: range.lowerBound)
            let end = pageText.distance(from: pageText.startIndex, to: range.upperBound)
            return start..<end
        }

        // Multiple occurrences: try to disambiguate using selection bounds
        let selectionBounds = selection.bounds(for: page)

        for range in ranges {
            let nsRange = NSRange(range, in: pageText)
            if let testSelection = page.selection(for: nsRange) {
                let testBounds = testSelection.bounds(for: page)
                // Check if bounds are approximately equal (within tolerance)
                if boundsApproximatelyEqual(selectionBounds, testBounds, tolerance: 5.0) {
                    let start = pageText.distance(from: pageText.startIndex, to: range.lowerBound)
                    let end = pageText.distance(from: pageText.startIndex, to: range.upperBound)
                    return start..<end
                }
            }
        }

        // Fallback: use first occurrence
        let range = ranges[0]
        let start = pageText.distance(from: pageText.startIndex, to: range.lowerBound)
        let end = pageText.distance(from: pageText.startIndex, to: range.upperBound)
        return start..<end
    }

    /// Extracts text context around the given range.
    private static func extractContext(
        around range: Range<Int>,
        in text: String,
        contextLength: Int
    ) -> (before: String?, after: String?) {
        let startIndex = text.index(text.startIndex, offsetBy: range.lowerBound)
        let endIndex = text.index(text.startIndex, offsetBy: range.upperBound)

        // Extract before context
        let beforeStart = text.index(
            startIndex,
            offsetBy: -contextLength,
            limitedBy: text.startIndex
        ) ?? text.startIndex
        let before = String(text[beforeStart..<startIndex])

        // Extract after context
        let afterEnd = text.index(
            endIndex,
            offsetBy: contextLength,
            limitedBy: text.endIndex
        ) ?? text.endIndex
        let after = String(text[endIndex..<afterEnd])

        return (
            before: before.isEmpty ? nil : before,
            after: after.isEmpty ? nil : after
        )
    }

    /// Checks if two bounds are approximately equal within a tolerance.
    private static func boundsApproximatelyEqual(
        _ a: CGRect,
        _ b: CGRect,
        tolerance: CGFloat
    ) -> Bool {
        abs(a.minX - b.minX) <= tolerance &&
        abs(a.minY - b.minY) <= tolerance &&
        abs(a.maxX - b.maxX) <= tolerance &&
        abs(a.maxY - b.maxY) <= tolerance
    }
}
