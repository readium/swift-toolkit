//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftSoup

/// Accessible name, description and extended descriptions of an HTML element.
///
/// The name and description are computed following a pragmatic subset of
/// https://www.w3.org/TR/accname-1.2. The extended descriptions are the
/// targets of the element's `aria-details` attribute, per the DAISY guidance:
/// https://daisy.github.io/transitiontoepub/best-practices/extended-desc/ExtendedDescriptionsBestPractices.html
///
/// This is the Swift counterpart of the TypeScript implementation in
/// `Sources/Navigator/EPUB/Scripts/src/accessibility-properties.ts` — both
/// MUST implement exactly the same subset. What keeps them in sync is the
/// shared case manifest in
/// `Tests/Samples/accessibility-properties/cases.toml`: it generates the
/// fixtures both test suites run against, so a rule is stated once and
/// asserted twice.
/// Add cases there, including caption cases; the `Figures` suite in
/// `HTMLResourceContentIteratorTests` keeps only iterator-structure
/// assertions.
///
/// Implemented:
/// - Source precedence for the name: `aria-labelledby` → `aria-label` →
///   host-language sources → `title`, matching the accname computation steps
///   "LabelledBy", "AriaLabel", "Host Language Label" and "Tooltip":
///   https://www.w3.org/TR/accname-1.2/#computation-steps
/// - Element-level suppression: `aria-hidden="true"` (accname "Hidden Not
///   Referenced" step: https://www.w3.org/TR/accname-1.2/#comp_hidden_not_referenced),
///   or a presentational `role` not cancelled by a global ARIA attribute
///   (WAI-ARIA "Presentational Roles Conflict Resolution":
///   https://www.w3.org/TR/wai-aria-1.2/#conflict_resolution_presentation_none),
///   yields no name and no description.
/// - The description cascade (`aria-describedby` → `aria-description` →
///   host-language sources → unused `title`) stops at the first PRESENT
///   markup, even if it resolves to an empty description:
///   https://www.w3.org/TR/accname-1.2/#mapping_additional_nd_description
/// - HTML-AAM 4.1.10 rules for `img`
///   (https://www.w3.org/TR/html-aam-1.0/#img-element-accessible-name-computation):
///   an empty `alt` attribute marks a decorative image and blocks the `title`
///   fallback (HTML-AAM overriding literal accname-1.2, whose "Tooltip" step,
///   https://www.w3.org/TR/accname-1.2/#comp_tooltip, would still name the
///   image from the tooltip; browsers follow HTML-AAM); a figcaption names an
///   image which has no `alt`/`title` attribute and no sibling content.
/// - Extended descriptions from `aria-details` on the element itself
///   (figure-level `aria-details` is ignored): each resolvable IDREF becomes a
///   `Link`, in attribute order. Dangling IDREFs are skipped; two IDREFs
///   resolving to the same node collapse to one (first wins); a target that is
///   the element itself or one of its ancestors is skipped. An `<a>` target
///   with a usable `href` (fragment, relative, or absolute http(s)) links to
///   its destination, titled by its `aria-label` or its text content; any
///   other target — a plain container, an `<a>` without `href`, with an empty
///   or bare-`#` `href`, or with a non-http(s) scheme (`mailto:`,
///   `javascript:`, …) — links to the target itself
///   (`<resource href>#<target id>`), titled only by its `aria-label`.
///   `aria-details` also counts as a global ARIA attribute in the
///   presentational-role conflict rule.
///
/// Deliberately skipped / divergences:
/// - Full recursive traversal of `aria-labelledby`/`aria-describedby` targets
///   (https://www.w3.org/TR/accname-1.2/#comp_labelledby); we approximate one
///   level: each target contributes its own `aria-label` when present, else
///   its text content. Nested images' `alt`, chained labelledby and embedded
///   form-control values
///   (https://www.w3.org/TR/accname-1.2/#comp_embedded_control) do not
///   contribute.
/// - Hidden-element rules beyond the element itself: hidden ancestors, and
///   the exclusion of hidden nodes inside referenced targets (requires CSS
///   knowledge SwiftSoup doesn't have; kept out of the DOM side too, for
///   parity).
/// - Roles that prohibit naming other than `presentation`/`none`
///   (https://www.w3.org/TR/wai-aria-1.2/#namefromprohibited); the
///   presentational-role conflict rule is narrowed to the four ARIA
///   attributes this helper reads (spec: any global ARIA attribute or
///   focusable element); unknown role tokens are not validated (the first
///   token wins).
/// - CSS generated content (`::before`/`::after`) and name-from-content
///   (https://www.w3.org/TR/accname-1.2/#comp_name_from_content).
/// - An `aria-describedby` whose IDREFs all dangle still counts as "the first
///   relevant markup found" and stops the description cascade (attribute
///   presence = found). The spec doesn't spell this out and browsers vary;
///   declared as a choice.
/// - HTML-AAM's figcaption-as-name fallback approximates the "no other
///   non-whitespace flow content descendants" condition: the figure's
///   normalized text must equal the figcaption's, and the figure must contain
///   no other embedded content.
/// - SVG `<a xlink:href>` targets of `aria-details`: only `href` is read, so
///   an SVG anchor carrying only `xlink:href` falls into the inline-container
///   branch.
/// - The text-content title of an `<a>` extended-description target joins its
///   text nodes and `img[alt]` values with a single space, so a word split
///   across adjacent inline elements gains a space that a browser's
///   `innerText` would not add.
/// - SwiftSoup's `text()` inserts a space before a block element when the
///   accumulated text does not already end in whitespace, while the DOM's
///   `textContent` does not, so `<figcaption>Cap<details>…` flattens to
///   `Cap More Body` here and to `CapMoreBody` in
///   `accessibility-properties.ts`. Real markup has whitespace between block
///   elements; the shared cases are authored that way. Making the two agree is
///   a follow-up.
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
    var extendedDescriptions: [Link] = []

    /// The computed properties as `ContentAttribute`s, ready to attach to a
    /// `ContentElement`.
    var contentAttributes: [ContentAttribute] {
        var attributes: [ContentAttribute] = []
        if let name = name {
            attributes.append(ContentAttribute(key: .accessibleName, value: name))
        }
        if let description = description {
            attributes.append(ContentAttribute(key: .accessibleDescription, value: description))
        }
        for link in extendedDescriptions {
            attributes.append(ContentAttribute(key: .extendedDescription, value: link))
        }
        return attributes
    }
}

extension SwiftSoup.Element {
    /// Computes the accessible name, description and extended descriptions of
    /// the receiver.
    ///
    /// - Parameter baseHREF: HREF of the resource holding the element, used
    ///   to resolve the extended description links.
    func accessibilityProperties(baseHREF: AnyURL?) throws -> HTMLAccessibilityProperties {
        let tag = tagNameNormal()
        let title = try attr("title").trimmingCharacters(in: .whitespacesAndNewlines).orNilIfBlank()

        // Step 0: element-level suppression (accname "Initialization" and
        // "Hidden Not Referenced" steps:
        // https://www.w3.org/TR/accname-1.2/#computation-steps).
        // `aria-hidden`, or a presentational role not cancelled by a global
        // ARIA attribute, prohibit both name and description. ARIA token
        // comparisons are case-insensitive; `role` is a token list with
        // first-token-wins semantics.
        let firstRole = try attr("role").lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .first { !$0.isEmpty }
        let hasGlobalARIAAttribute = hasAttr("aria-label") || hasAttr("aria-labelledby")
            || hasAttr("aria-describedby") || hasAttr("aria-description")
            || hasAttr("aria-details")
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
            name = try attr("aria-label").trimmingCharacters(in: .whitespacesAndNewlines).orNilIfEmpty()
        }

        // 3. Host-language source
        if name == nil {
            switch tag {
            case "img":
                if hasAttr("alt") {
                    name = try attr("alt").trimmingCharacters(in: .whitespacesAndNewlines).orNilIfEmpty()
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
        // https://www.w3.org/TR/html-aam-1.0/#img-element-accessible-name-computation
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
            description = try attr("aria-description").trimmingCharacters(in: .whitespacesAndNewlines).orNilIfEmpty()
        } else if tag == "svg", let desc = firstDirectChild(tag: "desc") {
            // 3. Host-language source
            description = try desc.text().orNilIfBlank()
        } else if !titleUsedAsName {
            // 4. title attribute, if not already used as the name
            description = title
        }

        return try HTMLAccessibilityProperties(
            name: name,
            description: description,
            extendedDescriptions: extendedDescriptionLinks(baseHREF: baseHREF)
        )
    }

    /// Resolves the element's `aria-details` IDREFs into extended description
    /// `Link`s, in attribute order.
    ///
    /// `aria-details` is a single ID reference in ARIA 1.2 and became an ID
    /// reference list in ARIA 1.3; the list handling is kept for forward
    /// compatibility and leniency with real content.
    private func extendedDescriptionLinks(baseHREF: AnyURL?) throws -> [Link] {
        guard hasAttr("aria-details"), let document = ownerDocument() else {
            return []
        }

        var links: [Link] = []
        var seenTargets: Set<ObjectIdentifier> = []
        for id in try attr("aria-details").components(separatedBy: .whitespacesAndNewlines) {
            guard
                !id.isEmpty,
                let target = try document.getElementById(id),
                // Two IDREFs resolving to the same node collapse (first wins).
                !seenTargets.contains(ObjectIdentifier(target)),
                // A target which is the element itself or one of its ancestors
                // would re-render the element it describes.
                !target.isSelfOrAncestor(of: self)
            else {
                continue
            }
            seenTargets.insert(ObjectIdentifier(target))
            try links.append(extendedDescriptionLink(target: target, id: id, baseHREF: baseHREF))
        }
        return links
    }

    /// Builds the `Link` for a single `aria-details` target.
    ///
    /// An `<a>` target with a usable `href` links to its destination; any
    /// other target is treated as an inline container and linked to in place.
    private func extendedDescriptionLink(target: Element, id: String, baseHREF: AnyURL?) throws -> Link {
        let ariaLabel = try target.attr("aria-label")
            .trimmingCharacters(in: .whitespacesAndNewlines).orNilIfEmpty()

        if
            target.tagNameNormal() == "a",
            let href = try target.anchorHREF(relativeTo: baseHREF)
        {
            return try Link(
                href: href,
                title: ariaLabel ?? target.extendedDescriptionTitle()
            )
        }

        // Inline container (or unusable anchor): link to the target itself.
        return Link(
            href: fragmentHREF(id: id, baseHREF: baseHREF),
            title: ariaLabel
        )
    }

    /// HREF of a link pointing to `id` inside the resource: the id
    /// percent-encoded as a fragment, resolved against the resource HREF.
    private func fragmentHREF(id: String, baseHREF: AnyURL?) -> String {
        let encodedID = id.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? id
        guard let fragment = RelativeURL(string: "#" + encodedID) else {
            return (baseHREF?.string ?? "") + "#" + encodedID
        }
        return (baseHREF?.resolve(fragment) ?? fragment.anyURL).string
    }

    /// Resolves the receiver's `href` attribute against the resource's base
    /// HREF, or returns `nil` when the anchor cannot be used as a link target:
    /// no `href`, an empty one, a bare `#`, one that is not a valid
    /// percent-encoded URL (documented divergence), or a scheme other than
    /// `http(s)` (`mailto:`, `javascript:`, …).
    ///
    /// Only `attr("href")` is read: an SVG `<a>` carrying only `xlink:href` is
    /// treated as an inline container (documented divergence).
    private func anchorHREF(relativeTo baseHREF: AnyURL?) throws -> String? {
        let href = try attr("href")
        guard !href.isEmpty, href != "#", let url = AnyURL(string: href) else {
            return nil
        }
        switch url {
        case let .absolute(url):
            // Reject unsafe or non-navigable schemes.
            guard url.scheme == .http || url.scheme == .https else {
                return nil
            }
            return url.string
        case .relative:
            // Also covers fragment-only hrefs, which resolve to
            // `<resource href>#<fragment>`.
            return (baseHREF?.resolve(url) ?? url).string
        }
    }

    /// Text-content title of an `<a>` extended description target: text nodes
    /// contribute their raw text, `img` elements their `alt` attribute, joined
    /// with a single space and whitespace-normalized.
    private func extendedDescriptionTitle() throws -> String? {
        var parts: [String] = []
        func visit(_ node: Node) throws {
            if let text = node as? TextNode {
                parts.append(text.getWholeText())
            } else if let element = node as? Element {
                if element.tagNameNormal() == "img" {
                    try parts.append(element.attr("alt"))
                } else {
                    for child in element.getChildNodes() {
                        try visit(child)
                    }
                }
            }
        }
        for child in getChildNodes() {
            try visit(child)
        }
        return parts.joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .orNilIfEmpty()
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
        try attr("aria-label").trimmingCharacters(in: .whitespacesAndNewlines).orNilIfEmpty()
            ?? text().orNilIfBlank()
    }

    func firstDirectChild(tag: String) -> Element? {
        children().first { $0.tagNameNormal() == tag }
    }

    /// Whether the receiver is `element` itself or one of its ancestors,
    /// mirroring the DOM's `Node.contains`, which includes the node itself.
    private func isSelfOrAncestor(of element: Element) -> Bool {
        self === element || element.parents().contains { $0 === self }
    }

    /// HTML-AAM 4.1.10 step 4, approximated: the figcaption names the image
    /// only when the figure holds no other non-whitespace flow content —
    /// checked as "the figure's normalized text equals the figcaption's, and
    /// the figure contains no other embedded content".
    /// https://www.w3.org/TR/html-aam-1.0/#img-element-accessible-name-computation
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
    ///
    /// An element living inside the figcaption (a publisher logo, a footnote
    /// marker) is not captioned by the text wrapping it, so it gets no
    /// caption at all rather than falling back to an outer figure.
    ///
    /// An extended description wrapped by the figcaption is excluded from the
    /// caption: any `<details>` subtree, and any subtree rooted at an element
    /// the receiver points at with `aria-details` or `aria-describedby`.
    /// Publishers do put the description inside the caption, and a reading app
    /// displaying the caption would otherwise print the whole long description
    /// — including one hidden by CSS, which a sighted reader never sees.
    ///
    /// The exclusion deliberately does NOT apply to the accessible name
    /// computed by `figureCaptionAsName()`: HTML-AAM 4.1.10 names the image
    /// from the whole figcaption.
    func figureCaption() throws -> String? {
        guard
            let figcaption = enclosingFigure()?.firstDirectChild(tag: "figcaption"),
            !parents().contains(where: { $0 === figcaption })
        else {
            return nil
        }

        let excludedIDs = try (attr("aria-details") + " " + attr("aria-describedby"))
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // The figcaption *is* the description: there is nothing left to
        // display. Checked explicitly because stripping cannot remove the root
        // of the subtree being stripped.
        guard try !excludedIDs.contains(figcaption.attr("id")) else {
            return nil
        }

        // A caption wrapping a description is the exception, and this runs for
        // every element of every resource, so look for something to strip
        // before paying for the deep copy below.
        let hasDetails = try !figcaption.getElementsByTag("details").isEmpty()
        let hasExcludedID = try excludedIDs.contains {
            try !figcaption.getElementsByAttributeValue("id", $0).isEmpty()
        }
        guard hasDetails || hasExcludedID else {
            return try figcaption.text().orNilIfBlank()
        }

        // Strip on a deep copy, to keep `text()`'s block-boundary spacing,
        // which a hand-rolled text walk would lose.
        guard let clone = figcaption.copy() as? Element else {
            return try figcaption.text().orNilIfBlank()
        }
        try clone.getElementsByTag("details").remove()
        for id in excludedIDs {
            // Matched by attribute value rather than with a `#id` selector, to
            // avoid CSS escaping.
            try clone.getElementsByAttributeValue("id", id).remove()
        }
        return try clone.text().orNilIfBlank()
    }
}
