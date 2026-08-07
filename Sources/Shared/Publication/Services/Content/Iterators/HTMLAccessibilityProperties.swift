//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftSoup

/// Accessible name and description of an HTML element, computed following a
/// pragmatic subset of https://www.w3.org/TR/accname-1.2
///
/// This is the Swift counterpart of the TypeScript implementation in
/// `Sources/Navigator/EPUB/Scripts/src/accname.ts` — both MUST implement
/// exactly the same subset. What keeps them in lockstep is the shared case
/// manifest in `scripts/accname-sample/cases.toml`: it generates the fixtures
/// both test suites run against, so a rule is stated once and asserted twice.
/// Add cases there.
///
/// Implemented:
/// - Source precedence for the name: `aria-labelledby` → `aria-label` →
///   host-language sources → `title`.
/// - Element-level suppression: `aria-hidden="true"`, or a presentational
///   `role` not cancelled by a global ARIA attribute, yields no name and no
///   description.
/// - The description cascade (`aria-describedby` → `aria-description` →
///   host-language sources → unused `title`) stops at the first PRESENT
///   markup, even if it resolves to an empty description.
/// - HTML-AAM 4.1.10 rules for `img`: an empty `alt` attribute marks a
///   decorative image and blocks the `title` fallback (HTML-AAM overriding
///   literal accname-1.2, whose step 2.9 would still name the image from the
///   tooltip; browsers follow HTML-AAM); a figcaption names an image which has
///   no `alt`/`title` attribute and no sibling content.
///
/// Deliberately skipped / divergences:
/// - Full recursive traversal of `aria-labelledby`/`aria-describedby` targets;
///   we approximate one level: each target contributes its own `aria-label`
///   when present, else its text content. Nested images' `alt`, chained
///   labelledby and embedded form-control values do not contribute.
/// - Hidden-element rules beyond the element itself: hidden ancestors, and
///   the exclusion of hidden nodes inside referenced targets (requires CSS
///   knowledge SwiftSoup doesn't have; kept out of the DOM side too, for
///   parity).
/// - Roles that prohibit naming other than `presentation`/`none`; the
///   presentational-role conflict rule is narrowed to the four ARIA
///   attributes this helper reads (spec: any global ARIA attribute or
///   focusable element); unknown role tokens are not validated (the first
///   token wins).
/// - CSS generated content (`::before`/`::after`) and name-from-content.
/// - An `aria-describedby` whose IDREFs all dangle still counts as "the first
///   relevant markup found" and stops the description cascade (attribute
///   presence = found). The spec doesn't spell this out and browsers vary;
///   declared as a choice.
/// - HTML-AAM's figcaption-as-name fallback approximates the "no other
///   non-whitespace flow content descendants" condition: the figure's
///   normalized text must equal the figcaption's, and the figure must contain
///   no other embedded content.
///
/// Reusability caveat: the ARIA-attribute sources apply to any element, but
/// host-language sources are implemented only for `img` and `svg`, and
/// name-from-content is not computed at all. The subset is exact for the
/// current consumers (img, svg, audio, video — roles that don't allow name
/// from content), but future element types have their own host-language
/// sources (e.g. `<table>` → `<caption>`, links/headings → content) that must
/// be added per-tag before pointing the helper at them.
struct HTMLAccessibilityProperties {
    var name: String?
    var description: String?

    /// The computed name/description as `ContentAttribute`s, ready to attach
    /// to a `ContentElement`.
    var contentAttributes: [ContentAttribute] {
        var attributes: [ContentAttribute] = []
        if let name = name {
            attributes.append(ContentAttribute(key: .accessibilityName, value: name))
        }
        if let description = description {
            attributes.append(ContentAttribute(key: .accessibilityDescription, value: description))
        }
        return attributes
    }
}

extension SwiftSoup.Element {
    /// Computes the accessible name and description of the receiver.
    func accessibilityProperties() throws -> HTMLAccessibilityProperties {
        let tag = tagNameNormal()
        let title = try attr("title").trimmingCharacters(in: .whitespacesAndNewlines).orNilIfBlank()

        // Step 0: element-level suppression (accname steps 1 and 2A).
        // `aria-hidden`, or a presentational role not cancelled by a global
        // ARIA attribute, prohibit both name and description. ARIA token
        // comparisons are case-insensitive; `role` is a token list with
        // first-token-wins semantics.
        let firstRole = try attr("role").lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .first { !$0.isEmpty }
        let hasGlobalARIAAttribute = hasAttr("aria-label") || hasAttr("aria-labelledby")
            || hasAttr("aria-describedby") || hasAttr("aria-description")
        if try attr("aria-hidden").lowercased() == "true"
            || ((firstRole == "presentation" || firstRole == "none") && !hasGlobalARIAAttribute)
        {
            return HTMLAccessibilityProperties(name: nil, description: nil)
        }

        var name: String?
        var stopNameCascade = false

        // 1. aria-labelledby
        name = try resolveIDReferences(attr("aria-labelledby"))

        // 2. aria-label
        if name == nil {
            name = try attr("aria-label").trimmingCharacters(in: .whitespacesAndNewlines).orNilIfBlank()
        }

        // 3. Host-language source
        if name == nil {
            switch tag {
            case "img":
                if hasAttr("alt") {
                    name = try attr("alt").trimmingCharacters(in: .whitespacesAndNewlines).orNilIfBlank()
                    if name == nil {
                        // `alt=""` marks a decorative image: no fallback on
                        // `title`, per HTML-AAM 4.1.10.
                        stopNameCascade = true
                    }
                }
            case "svg":
                name = try firstDirectChild(tag: "title")?.text().orNilIfBlank()
            default:
                break
            }
        }

        // 4. title attribute
        var titleUsedAsName = false
        if name == nil, !stopNameCascade, let title = title {
            name = title
            titleUsedAsName = true
        }

        // 5. HTML-AAM 4.1.10 step 4: an img with no alt or title attribute,
        // alone in a captioned figure, takes its name from the figcaption.
        if name == nil, tag == "img", !hasAttr("alt"), !hasAttr("title") {
            name = try figureCaptionAsName()
        }

        // The description cascade stops at the first PRESENT markup, even if
        // it resolves to an empty description ("MUST NOT use any markup other
        // than the first relevant markup found").
        var description: String?
        if hasAttr("aria-describedby") {
            // 1. aria-describedby
            description = try resolveIDReferences(attr("aria-describedby"))
        } else if hasAttr("aria-description") {
            // 2. aria-description
            description = try attr("aria-description").trimmingCharacters(in: .whitespacesAndNewlines).orNilIfBlank()
        } else if tag == "svg", let desc = firstDirectChild(tag: "desc") {
            // 3. Host-language source
            description = try desc.text().orNilIfBlank()
        } else if !titleUsedAsName {
            // 4. title attribute, if not already used as the name
            description = title
        }

        return HTMLAccessibilityProperties(name: name, description: description)
    }

    /// Resolves a space-separated list of element IDs against the document and
    /// concatenates the referenced elements' text alternatives, per the
    /// `aria-labelledby` and `aria-describedby` steps of the accessible name
    /// computation.
    ///
    /// One-level approximation of the spec's recursive computation: each
    /// referenced element contributes its own `aria-label` when present,
    /// otherwise its text content.
    private func resolveIDReferences(_ ids: String) throws -> String? {
        guard let document = ownerDocument() else {
            return nil
        }
        return try ids.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .compactMap { try document.getElementById($0)?.textAlternative() }
            .joined(separator: " ")
            .orNilIfBlank()
    }

    /// The receiver's contribution when referenced by `aria-labelledby` or
    /// `aria-describedby`: its `aria-label` when present, else its text content.
    private func textAlternative() throws -> String? {
        try attr("aria-label").trimmingCharacters(in: .whitespacesAndNewlines).orNilIfBlank()
            ?? text().orNilIfBlank()
    }

    func firstDirectChild(tag: String) -> Element? {
        children().first { $0.tagNameNormal() == tag }
    }

    /// HTML-AAM 4.1.10 step 4, approximated: the figcaption names the image
    /// only when the figure holds no other non-whitespace flow content —
    /// checked as "the figure's normalized text equals the figcaption's, and
    /// the figure contains no other embedded content".
    private func figureCaptionAsName() throws -> String? {
        guard
            let figure = enclosingFigure(),
            let figcaption = figure.firstDirectChild(tag: "figcaption")
        else {
            return nil
        }
        guard
            try figure.text() == figcaption.text(),
            try figure.select("img, svg, audio, video, object, iframe, embed")
            .allSatisfy({ $0 === self })
        else {
            return nil
        }
        return try figcaption.text().orNilIfBlank()
    }
}

/// Shared with `HTMLResourceContentIterator` (which uses them for the
/// `caption` property).
extension SwiftSoup.Element {
    /// Nearest ancestor `<figure>` element.
    func enclosingFigure() -> Element? {
        parents().first { $0.tagNameNormal() == "figure" }
    }

    /// Returns the text of the enclosing `<figure>`'s direct `<figcaption>`
    /// child, if any.
    func figureCaption() throws -> String? {
        try enclosingFigure()?
            .firstDirectChild(tag: "figcaption")?
            .text()
            .orNilIfBlank()
    }
}
