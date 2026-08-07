//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A candidate piece of fixed-layout text which might be a hard break:
/// standalone display text (a part or chapter heading, a title page line)
/// which is not part of any sentence.
///
/// Unlike a page artifact, a hard break is real reading-order content: it is
/// spoken by TTS and searchable. But it forms its own standalone element, and
/// sentences are never merged across it.
public struct HardBreakCandidate: Sendable {
    /// Candidate text, trimmed of surrounding whitespace.
    public var text: String

    /// Role of the element the candidate comes from.
    public var role: TextContentElement.Role

    /// Whether the candidate is the only body text on its page (e.g. a title
    /// page).
    public var isWholePage: Bool

    public init(
        text: String,
        role: TextContentElement.Role = .body,
        isWholePage: Bool = false
    ) {
        self.text = text
        self.role = role
        self.isWholePage = isWholePage
    }
}

/// Detects hard breaks in fixed-layout content: standalone display text which
/// must never be merged into a surrounding sentence.
public protocol HardBreakDetector: Sendable {
    /// Returns whether `candidate` is a hard break.
    func isHardBreak(_ candidate: HardBreakCandidate) -> Bool
}

/// Detects all-caps display lines, such as "P A R T O N E", "PROLOGUE" or
/// "PART ONE".
///
/// A candidate is a hard break when it contains no lowercase letters, has at
/// least 3 uppercase letters, is at most 60 characters long and has no
/// terminal punctuation. This excludes shouted sentences ("STOP RIGHT
/// THERE!"), mixed-case lines containing acronyms, and case-less scripts
/// (CJK).
public struct SpacedCapsHardBreakDetector: HardBreakDetector {
    public init() {}

    public func isHardBreak(_ candidate: HardBreakCandidate) -> Bool {
        let text = candidate.text
        guard
            text.count <= 60,
            !text.contains(where: \.isLowercase),
            text.filter(\.isUppercase).count >= 3,
            !endsWithTerminalPunctuation(text)
        else {
            return false
        }
        return true
    }
}

/// Detects section headings: elements with a `heading` role (EPUB FXL), or
/// "Chapter 12"-style lines (PDF).
public struct HeadingHardBreakDetector: HardBreakDetector {
    public init() {}

    public func isHardBreak(_ candidate: HardBreakCandidate) -> Bool {
        if case .heading = candidate.role {
            return true
        }

        let text = candidate.text
        guard text.count <= 60, !endsWithTerminalPunctuation(text) else {
            return false
        }
        return text.lowercased().range(
            of: "^(chapter|chapitre|part|partie|book|section|prologue|epilogue|act|scene)\\b[\\s.:]*([0-9]{1,4}|[ivxlcdm]{1,8})?$",
            options: .regularExpression
        ) != nil
    }
}

/// Detects short punctuation-less standalone pages, such as a title page
/// holding only "The Great Gatsby".
public struct StandalonePageHardBreakDetector: HardBreakDetector {
    public init() {}

    public func isHardBreak(_ candidate: HardBreakCandidate) -> Bool {
        guard candidate.isWholePage else {
            return false
        }
        let text = candidate.text
        let hyphens: Set<Character> = ["-", "\u{2010}", "\u{00AD}"]
        guard
            !text.isEmpty,
            text.count <= 60,
            !endsWithTerminalPunctuation(text),
            // A page starting lowercase or ending with a word cut is the
            // middle of a sentence spilling across pages, not a display page.
            text.first(where: \.isLetter)?.isLowercase != true,
            text.last.map({ !hyphens.contains($0) }) == true
        else {
            return false
        }

        // Titles are title-cased ("The Lord of the Rings"); a sentence
        // spilling onto the next page is not ("The story begins with").
        let words = text.split(whereSeparator: \.isWhitespace)
            .filter { $0.contains(where: \.isLetter) }
        guard !words.isEmpty else {
            return false
        }
        let capitalized = words.filter { $0.first(where: \.isLetter)?.isUppercase == true }
        return Double(capitalized.count) / Double(words.count) >= 0.5
    }
}

/// Returns whether the text ends a sentence, i.e. finishes with terminal
/// punctuation, possibly followed by closing quotes or brackets.
func endsWithTerminalPunctuation(_ text: String) -> Bool {
    let closers: Set<Character> = ["\"", "'", "”", "’", "»", "›", ")", "]", "}"]
    let terminals: Set<Character> = [".", "!", "?", "…", "。", "！", "？"]
    var text = Substring(text.trimmingCharacters(in: .whitespacesAndNewlines))
    while let last = text.last, closers.contains(last) {
        text = text.dropLast()
    }
    guard let last = text.last else {
        return false
    }
    return terminals.contains(last)
}
