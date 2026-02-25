//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// MARK: - Text Selector

/// Identifies a position or a range of text within a resource.
public enum TextSelector: Hashable, Sendable {
    /// Pinpoints a reference using surrounding text context, without selecting a
    /// range.
    case position(TextPosition)

    /// Selects an exact text range by quoting the target text and its
    /// surroundings.
    case quote(TextQuote)
}

/// Identifies a text range by quoting the exact text and its surrounding
/// context.
///
/// Inspired by the W3C Text Quote Selector and the WICG Scroll-to-Text Fragment
/// specifications.
///
/// - https://wicg.github.io/scroll-to-text-fragment/
/// - https://www.w3.org/TR/annotation-model/#text-quote-selector
public struct TextQuote: Hashable, Sendable {
    /// Text immediately preceding the selected range, used to disambiguate
    /// matches.
    public var before: String

    /// First text of the selected range.
    public var start: String

    /// Last text of the selected range. Empty when the quote is entirely
    /// contained within `start`.
    public var end: String

    /// Text immediately following the selected range, used to disambiguate
    /// matches.
    public var after: String

    public init(
        before: String = "",
        start: String,
        end: String = "",
        after: String = ""
    ) {
        self.before = before
        self.start = start
        self.end = end
        self.after = after
    }
}

/// Identifies a position within a text resource using surrounding text context,
/// without selecting a range.
///
/// Inspired by the W3C Text Position Selector and the WICG Scroll-to-Text
/// Fragment specifications.
///
/// - https://wicg.github.io/scroll-to-text-fragment/
/// - https://www.w3.org/TR/annotation-model/#text-position-selector
public struct TextPosition: Hashable, Sendable {
    /// Text immediately before the position.
    public var before: String

    /// Text immediately after the position.
    public var after: String

    public init(
        before: String = "",
        after: String = ""
    ) {
        self.before = before
        self.after = after
    }
}

// MARK: - Fragment

public extension TextSelector {
    /// Creates a ``TextSelector`` from a URL fragment following the WICG
    /// Scroll-to-Text Fragment specification.
    ///
    /// Fragment format: `:~:text=[prefix-,]textStart[,textEnd][,-suffix]`
    ///
    /// - https://wicg.github.io/scroll-to-text-fragment/
    init?(fragment: URLFragment) {
        let raw = fragment.rawValue
        let prefix = ":~:text="
        guard raw.hasPrefix(prefix) else { return nil }
        let directive = String(raw.dropFirst(prefix.count))
        guard !directive.isEmpty else { return nil }

        var parts = directive.components(separatedBy: ",")

        var before = ""
        var after = ""

        // Check for context prefix (ends with `-`)
        if parts[0].hasSuffix("-") {
            let encoded = String(parts[0].dropLast())
            before = encoded.removingPercentEncoding ?? encoded
            parts.removeFirst()
        }

        // Check for context suffix (starts with `-`)
        if let last = parts.last, last.hasPrefix("-") {
            let encoded = String(last.dropFirst())
            after = encoded.removingPercentEncoding ?? encoded
            parts.removeLast()
        }

        guard !parts.isEmpty, !parts[0].isEmpty else { return nil }

        let startEncoded = parts[0]
        let start = startEncoded.removingPercentEncoding ?? startEncoded

        var end = ""
        if parts.count >= 2 {
            let endEncoded = parts[1]
            end = endEncoded.removingPercentEncoding ?? endEncoded
        }

        self = .quote(TextQuote(before: before, start: start, end: end, after: after))
    }

    /// Returns a URL fragment representation of this selector following the
    /// WICG Scroll-to-Text Fragment specification.
    ///
    /// - https://wicg.github.io/scroll-to-text-fragment/
    var fragment: URLFragment {
        switch self {
        case let .quote(q):
            var parts: [String] = []
            let allowed = CharacterSet.urlQueryAllowed
            if !q.before.isEmpty {
                parts.append((q.before.addingPercentEncoding(withAllowedCharacters: allowed) ?? q.before) + "-")
            }
            parts.append(q.start.addingPercentEncoding(withAllowedCharacters: allowed) ?? q.start)
            if !q.end.isEmpty {
                parts.append(q.end.addingPercentEncoding(withAllowedCharacters: allowed) ?? q.end)
            }
            if !q.after.isEmpty {
                parts.append("-" + (q.after.addingPercentEncoding(withAllowedCharacters: allowed) ?? q.after))
            }
            return URLFragment(rawValue: ":~:text=" + parts.joined(separator: ","))!

        case let .position(p):
            var parts: [String] = []
            let allowed = CharacterSet.urlQueryAllowed
            if !p.before.isEmpty {
                parts.append((p.before.addingPercentEncoding(withAllowedCharacters: allowed) ?? p.before) + "-")
            }
            // No start text for a pure position — emit an empty start segment
            parts.append("")
            if !p.after.isEmpty {
                parts.append("-" + (p.after.addingPercentEncoding(withAllowedCharacters: allowed) ?? p.after))
            }
            return URLFragment(rawValue: ":~:text=" + parts.joined(separator: ","))!
        }
    }
}

public extension URLFragment {
    /// Parses the fragment as a ``TextSelector`` following the WICG
    /// Scroll-to-Text Fragment specification.
    var textSelector: TextSelector? {
        TextSelector(fragment: self)
    }
}
