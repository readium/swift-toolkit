//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Kind of page-boundary noise found in fixed-layout content.
public enum PageArtifactKind: String, Hashable, Sendable {
    /// A standalone page number (e.g. "42", "- 42 -", "xii", "Page 42").
    case pageNumber

    /// A running header or footer repeated on consecutive pages (e.g. the
    /// book or chapter title).
    case runningHeader
}

/// How the continuation of a cross-page sentence is joined to its first part.
public enum ContentContinuationJoiner: String, Hashable, Sendable {
    /// The parts are joined with a single space (regular word boundary).
    case space

    /// The parts are joined directly, without any separator (the first part
    /// ended with a hyphenated word cut).
    case direct
}

public extension ContentAttributeKey {
    /// Marks a `ContentElement` or `TextContentElement.Segment` as
    /// page-boundary noise which should not be spoken by TTS.
    static var pageArtifact: ContentAttributeKey<PageArtifactKind> {
        .init("pageArtifact")
    }

    /// Marks a segment as the cross-page continuation of the sentence started
    /// in the immediately preceding segment.
    ///
    /// The value indicates how to join the segment to the previous one to
    /// reconstruct the full sentence.
    static var continued: ContentAttributeKey<ContentContinuationJoiner> {
        .init("continued")
    }
}

/// A candidate piece of text sitting at the edge of a fixed-layout page,
/// which might be page-boundary noise (page number, running header, etc.).
public struct PageArtifactCandidate: Sendable {
    /// Edge of the page the candidate sits on.
    public enum Edge: Sendable {
        case head, tail
    }

    /// Granularity of the candidate.
    public enum Scope: Sendable {
        /// A single line within a page text blob (e.g. a PDF page).
        case line

        /// A whole standalone element of a page (e.g. in a fixed-layout EPUB
        /// where the page number is its own element).
        case element
    }

    /// Candidate text, trimmed of surrounding whitespace.
    public var text: String

    /// Edge of the page the candidate sits on.
    public var edge: Edge

    /// Granularity of the candidate.
    public var scope: Scope

    /// Text found at the same edge of the previous page, if known.
    ///
    /// `nil` at the edges of the publication or when the neighboring page has
    /// not been observed yet; detectors must tolerate its absence.
    public var previousPageEdgeText: String?

    /// Text found at the same edge of the next page, if known.
    public var nextPageEdgeText: String?

    public init(
        text: String,
        edge: Edge,
        scope: Scope,
        previousPageEdgeText: String? = nil,
        nextPageEdgeText: String? = nil
    ) {
        self.text = text
        self.edge = edge
        self.scope = scope
        self.previousPageEdgeText = previousPageEdgeText
        self.nextPageEdgeText = nextPageEdgeText
    }
}

/// Detects page-boundary noise (page numbers, running headers) in
/// fixed-layout content.
public protocol PageArtifactDetector: Sendable {
    /// Whether this detector needs the neighboring pages' edge text to work.
    ///
    /// Neighbor-free detectors can run early, before any lookahead of the next
    /// page is available.
    var requiresNeighbors: Bool { get }

    /// Returns the kind of artifact `candidate` is, or `nil` if it looks like
    /// regular content.
    func detectArtifact(in candidate: PageArtifactCandidate) -> PageArtifactKind?
}

/// Detects standalone page numbers, without needing the neighboring pages.
///
/// Recognizes arabic numbers (up to 4 digits), roman numerals (up to 8
/// characters) and common decorations such as "- 42 -", "Page 42" or
/// "42 / 300".
public struct PageNumberArtifactDetector: PageArtifactDetector {
    public init() {}

    public var requiresNeighbors: Bool { false }

    public func detectArtifact(in candidate: PageArtifactCandidate) -> PageArtifactKind? {
        isPageNumber(candidate.text) ? .pageNumber : nil
    }

    private func isPageNumber(_ text: String) -> Bool {
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 24 else {
            return false
        }

        // Strip symmetric decorations, e.g. "- 42 -", "— 42 —", "[42]", "(42)".
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "-–—•·*[]()|. \u{00A0}"))

        // "Page 42", "page 42", "p. 42", "P42".
        for prefix in ["page", "p."] {
            if text.lowercased().hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        // "42 / 300", "42 of 300".
        for separator in ["/", " of "] {
            if let range = text.range(of: separator) {
                let lhs = text[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                let rhs = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
                return isBareNumber(lhs) && isBareNumber(rhs)
            }
        }

        return isBareNumber(text)
    }

    private func isBareNumber(_ text: String) -> Bool {
        guard !text.isEmpty else {
            return false
        }

        if text.count <= 4, text.allSatisfy({ $0.isASCII && $0.isNumber }) {
            return true
        }

        return isRomanNumeral(text)
    }

    private func isRomanNumeral(_ text: String) -> Bool {
        // Roman page numbers are consistently cased ("xii" or "XII"), which
        // rules out regular words such as "Mix" or "Civil".
        guard
            text.count <= 8,
            text == text.lowercased() || text == text.uppercased()
        else {
            return false
        }

        // Validates the numeral structure, to avoid flagging words made of
        // roman digits only ("civil", "did", "mild").
        return text.lowercased().range(
            of: "^m{0,4}(cm|cd|d?c{0,3})(xc|xl|l?x{0,3})(ix|iv|v?i{0,3})$",
            options: .regularExpression
        ) != nil && !text.isEmpty
    }
}

/// Detects running headers and footers by comparing a page edge with the same
/// edge of the neighboring pages.
///
/// A candidate is considered a running header when its normalized text (case
/// folded, digits and punctuation stripped) is non-trivial and matches the
/// neighboring page's.
public struct RunningHeaderArtifactDetector: PageArtifactDetector {
    /// Minimum length of the normalized text to consider a match, to avoid
    /// false positives on very short lines.
    private let minimumLength: Int

    public init(minimumLength: Int = 4) {
        self.minimumLength = minimumLength
    }

    public var requiresNeighbors: Bool { true }

    public func detectArtifact(in candidate: PageArtifactCandidate) -> PageArtifactKind? {
        let text = normalize(candidate.text)
        guard text.count >= minimumLength else {
            return nil
        }

        let neighbors = [candidate.previousPageEdgeText, candidate.nextPageEdgeText]
            .compactMap { $0.map(normalize) }

        return neighbors.contains(text) ? .runningHeader : nil
    }

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .filter { $0.isLetter || $0.isWhitespace }
            .coalescingWhitespaces()
            .trimmingCharacters(in: .whitespaces)
    }
}
