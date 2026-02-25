//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// MARK: - CSS Selector

/// A CSS selector string targeting an element or range within an HTML/XHTML
/// resource.
public struct CSSSelector: Hashable, Sendable {
    public var cssSelector: String

    public init(cssSelector: String) {
        self.cssSelector = cssSelector
    }

    /// The HTML element ID targeted by this selector, if the rightmost simple
    /// selector is a plain ID selector (e.g. `#section1` or `.nav #section1`
    /// → `"section1"`).
    ///
    /// Returns `nil` when the target element is not identified by a simple
    /// `#id` form (e.g. `#foo .bar` targets `.bar`, so returns `nil`).
    public var htmlID: String? {
        // Split on CSS combinators (whitespace, >, +, ~) to isolate simple selectors.
        let parts = cssSelector
            .components(separatedBy: CharacterSet(charactersIn: ">+~").union(.whitespaces))
            .filter { !$0.isEmpty }
        guard let last = parts.last,
              last.hasPrefix("#"),
              last.count > 1,
              !last.dropFirst().contains(where: { !$0.isLetter && !$0.isNumber && $0 != "-" && $0 != "_" })
        else { return nil }
        return String(last.dropFirst())
    }
}

// MARK: - Fragment

public extension CSSSelector {
    /// Creates a ``CSSSelector`` from a URL fragment by treating it as an HTML
    /// element ID.
    ///
    /// A plain fragment (e.g. `section1`) is converted to a CSS ID selector
    /// (e.g. `#section1`).
    ///
    /// - Important: This initializer accepts any non-empty fragment string,
    ///   including structured directives such as `:~:text=…` or `t=…`. Callers
    ///   are responsible for trying more specific ``TextSelector`` or
    ///   ``TemporalSelector`` initializers first.
    init(fragment: URLFragment) {
        self.init(cssSelector: "#\(fragment.rawValue)")
    }
}

public extension URLFragment {
    /// Interprets the fragment as an HTML element ID and returns a
    /// ``CSSSelector``.
    var cssSelector: CSSSelector {
        CSSSelector(fragment: self)
    }
}
