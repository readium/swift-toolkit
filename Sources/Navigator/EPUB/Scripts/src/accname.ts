//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

/**
 * Accessible name, description and extended descriptions of an HTML element.
 *
 * The name and description are computed following a pragmatic subset of
 * https://www.w3.org/TR/accname-1.2. The extended descriptions are the
 * targets of the element's `aria-details` attribute, per the DAISY guidance:
 * https://daisy.github.io/transitiontoepub/best-practices/extended-desc/ExtendedDescriptionsBestPractices.html
 *
 * This is the TypeScript counterpart of the Swift implementation in
 * `Sources/Shared/Publication/Services/Content/Iterators/HTMLAccessibilityProperties.swift`
 * — both MUST implement exactly the same subset. What keeps them in sync is
 * the shared case manifest in `scripts/accname-sample/cases.toml`: it generates
 * the fixtures both test suites run against, so a rule is stated once and
 * asserted twice. Add cases there, including caption cases; the `Figures` suite
 * in the Swift `HTMLResourceContentIteratorTests` keeps only
 * iterator-structure assertions.
 *
 * Implemented:
 * - Source precedence for the name: `aria-labelledby` → `aria-label` →
 *   host-language sources → `title`, matching the accname computation steps
 *   "LabelledBy", "AriaLabel", "Host Language Label" and "Tooltip":
 *   https://www.w3.org/TR/accname-1.2/#computation-steps
 * - Element-level suppression: `aria-hidden="true"` (accname "Hidden Not
 *   Referenced" step: https://www.w3.org/TR/accname-1.2/#comp_hidden_not_referenced),
 *   or a presentational `role` not cancelled by a global ARIA attribute
 *   (WAI-ARIA "Presentational Roles Conflict Resolution":
 *   https://www.w3.org/TR/wai-aria-1.2/#conflict_resolution_presentation_none),
 *   yields no name and no description.
 * - The description cascade (`aria-describedby` → `aria-description` →
 *   host-language sources → unused `title`) stops at the first PRESENT
 *   markup, even if it resolves to an empty description:
 *   https://www.w3.org/TR/accname-1.2/#mapping_additional_nd_description
 * - HTML-AAM 4.1.10 rules for `img`
 *   (https://www.w3.org/TR/html-aam-1.0/#img-element-accessible-name-computation):
 *   an empty `alt` attribute marks a decorative image and blocks the `title`
 *   fallback (HTML-AAM overriding literal accname-1.2, whose "Tooltip" step,
 *   https://www.w3.org/TR/accname-1.2/#comp_tooltip, would still name the
 *   image from the tooltip; browsers follow HTML-AAM); a figcaption names an
 *   image which has no `alt`/`title` attribute and no sibling content.
 * - Extended descriptions from `aria-details` on the element itself
 *   (figure-level `aria-details` is ignored): each resolvable IDREF becomes a
 *   link, in attribute order. Dangling IDREFs are skipped; two IDREFs
 *   resolving to the same node collapse to one (first wins); a target that is
 *   the element itself or one of its ancestors is skipped. An `<a>` target
 *   with a usable `href` (fragment, relative, or absolute http(s)) links to
 *   its destination, titled by its `aria-label` or its text content; any
 *   other target — a plain container, an `<a>` without `href`, with an empty
 *   or bare-`#` `href`, or with a non-http(s) scheme (`mailto:`,
 *   `javascript:`, …) — links to the target itself (`<base URI>#<target id>`),
 *   titled only by its `aria-label`. `aria-details` also counts as a global
 *   ARIA attribute in the presentational-role conflict rule.
 *
 * Deliberately skipped / divergences:
 * - Full recursive traversal of `aria-labelledby`/`aria-describedby` targets
 *   (https://www.w3.org/TR/accname-1.2/#comp_labelledby); we approximate one
 *   level: each target contributes its own `aria-label` when present, else
 *   its text content. Nested images' `alt`, chained labelledby and embedded
 *   form-control values
 *   (https://www.w3.org/TR/accname-1.2/#comp_embedded_control) do not
 *   contribute.
 * - Hidden-element rules beyond the element itself: hidden ancestors, and the
 *   exclusion of hidden nodes inside referenced targets (kept out of the DOM
 *   side for parity with the Swift implementation, which has no CSS
 *   knowledge).
 * - Roles that prohibit naming other than `presentation`/`none`
 *   (https://www.w3.org/TR/wai-aria-1.2/#namefromprohibited); the
 *   presentational-role conflict rule is narrowed to the four ARIA attributes
 *   this helper reads (spec: any global ARIA attribute or focusable element);
 *   unknown role tokens are not validated (the first token wins).
 * - CSS generated content (`::before`/`::after`) and name-from-content
 *   (https://www.w3.org/TR/accname-1.2/#comp_name_from_content).
 * - An `aria-describedby` whose IDREFs all dangle still counts as "the first
 *   relevant markup found" and stops the description cascade (attribute
 *   presence = found). The spec doesn't spell this out and browsers vary;
 *   declared as a choice.
 * - HTML-AAM's figcaption-as-name fallback approximates the "no other
 *   non-whitespace flow content descendants" condition: the figure's
 *   normalized text must equal the figcaption's, and the figure must contain
 *   no other embedded content.
 * - SVG `<a xlink:href>` targets of `aria-details`: only `href` is read, so
 *   an SVG anchor carrying only `xlink:href` falls into the inline-container
 *   branch.
 * - The text-content title of an `<a>` extended-description target joins its
 *   text nodes and `img[alt]` values with a single space, so a word split
 *   across adjacent inline elements gains a space that a browser's
 *   `innerText` would not add.
 * - `textContent` runs block elements together, while SwiftSoup's `text()`
 *   inserts a space before them, so `<figcaption>Cap<details>…` flattens to
 *   `CapMoreBody` here and to `Cap More Body` on the Swift side. Real markup
 *   has whitespace between block elements; the shared cases are authored that
 *   way. Making the two agree is a follow-up.
 *
 * Reusability caveat: the ARIA-attribute sources apply to any element, but
 * host-language sources are implemented only for `img` and `svg`, and
 * name-from-content is not computed at all. The subset is exact for the
 * current consumers (img, svg, audio, video — roles that don't allow name
 * from content), but future element types have their own host-language
 * sources (e.g. `<table>` → `<caption>`, links/headings → content) that must
 * be added per-tag before pointing the helper at them.
 */

export interface AccessibilityProperties {
  name: string | null;
  description: string | null;
  extendedDescriptions: ExtendedDescription[];
}

/** A link to an extended description, resolved from `aria-details`. */
export interface ExtendedDescription {
  /** Absolute URL of the description, resolved against the base URI. */
  href: string;
  title: string | null;
}

/**
 * Computes the accessible name, description and extended descriptions of an
 * element, following a pragmatic subset of https://www.w3.org/TR/accname-1.2
 *
 * `baseURI` is the URI extended description links are resolved against; it
 * defaults to the element's document base URI.
 */
export function computeAccessibilityProperties(
  element: Element,
  baseURI: string = element.ownerDocument.baseURI
): AccessibilityProperties {
  const tag = element.tagName.toLowerCase();
  const title = element.getAttribute("title")?.trim() || null;

  // Step 0: element-level suppression (accname "Initialization" and "Hidden
  // Not Referenced" steps: https://www.w3.org/TR/accname-1.2/#computation-steps).
  // `aria-hidden`, or a presentational role not cancelled by a global ARIA
  // attribute, prohibit both name and description. ARIA token comparisons are
  // case-insensitive; `role` is a token list with first-token-wins semantics.
  const firstRole = element
    .getAttribute("role")
    ?.toLowerCase()
    .split(/\s+/)
    .find((token) => token.length > 0);
  const hasGlobalARIAAttribute =
    element.hasAttribute("aria-label") ||
    element.hasAttribute("aria-labelledby") ||
    element.hasAttribute("aria-describedby") ||
    element.hasAttribute("aria-description") ||
    element.hasAttribute("aria-details");
  if (
    element.getAttribute("aria-hidden")?.toLowerCase() === "true" ||
    ((firstRole === "presentation" || firstRole === "none") &&
      !hasGlobalARIAAttribute)
  ) {
    // A suppressed element is out of the accessibility tree, relations
    // included, so it gets no extended descriptions either.
    return { name: null, description: null, extendedDescriptions: [] };
  }

  let name: string | null = null;
  let stopNameCascade = false;

  // 1. aria-labelledby
  name = resolveIDReferences(element, "aria-labelledby");

  // 2. aria-label
  if (!name) {
    name = element.getAttribute("aria-label")?.trim() || null;
  }

  // 3. Host-language source
  if (!name) {
    if (tag === "img") {
      if (element.hasAttribute("alt")) {
        name = element.getAttribute("alt")!.trim() || null;
        if (!name) {
          // `alt=""` marks a decorative image: no fallback on `title`, per
          // HTML-AAM 4.1.10.
          stopNameCascade = true;
        }
      }
    } else if (tag === "svg") {
      name = firstDirectChildText(element, "title");
    }
  }

  // 4. title attribute
  let titleUsedAsName = false;
  if (!name && !stopNameCascade && title) {
    name = title;
    titleUsedAsName = true;
  }

  // 5. HTML-AAM 4.1.10 step 4: an img with no alt or title attribute, alone
  // in a captioned figure, takes its name from the figcaption.
  // https://www.w3.org/TR/html-aam-1.0/#img-element-accessible-name-computation
  if (
    !name &&
    tag === "img" &&
    !element.hasAttribute("alt") &&
    !element.hasAttribute("title")
  ) {
    name = figureCaptionAsName(element);
  }

  // The description cascade stops at the first PRESENT markup, even if it
  // resolves to an empty description ("MUST NOT use any markup other than the
  // first relevant markup found").
  let description: string | null = null;
  if (element.hasAttribute("aria-describedby")) {
    // 1. aria-describedby
    description = resolveIDReferences(element, "aria-describedby");
  } else if (element.hasAttribute("aria-description")) {
    // 2. aria-description
    description = element.getAttribute("aria-description")!.trim() || null;
  } else if (tag === "svg" && element.querySelector(":scope > desc")) {
    // 3. Host-language source
    description = firstDirectChildText(element, "desc");
  } else if (!titleUsedAsName) {
    // 4. title attribute, if not already used as the name.
    description = title;
  }

  return {
    name,
    description,
    extendedDescriptions: computeExtendedDescriptions(element, baseURI),
  };
}

/**
 * Resolves the element's `aria-details` IDREFs into extended description
 * links, in attribute order.
 *
 * `aria-details` is a single ID reference in ARIA 1.2 and became an ID
 * reference list in ARIA 1.3; the list handling is kept for forward
 * compatibility and leniency with real content.
 */
function computeExtendedDescriptions(
  element: Element,
  baseURI: string
): ExtendedDescription[] {
  const ids = element.getAttribute("aria-details");
  if (!ids) {
    return [];
  }

  const links: ExtendedDescription[] = [];
  const seenTargets = new Set<Element>();
  for (const id of ids.split(/\s+/)) {
    if (id.length === 0) {
      continue;
    }
    const target = element.ownerDocument.getElementById(id);
    if (
      !target ||
      // Two IDREFs resolving to the same node collapse (first wins).
      seenTargets.has(target) ||
      // A target which is the element itself or one of its ancestors would
      // re-render the element it describes. `contains` includes the element
      // itself.
      target.contains(element)
    ) {
      continue;
    }
    seenTargets.add(target);
    links.push(extendedDescriptionLink(target, id, baseURI));
  }
  return links;
}

/**
 * Builds the link for a single `aria-details` target.
 *
 * An `<a>` target with a usable `href` links to its destination; any other
 * target is treated as an inline container and linked to in place.
 */
function extendedDescriptionLink(
  target: Element,
  id: string,
  baseURI: string
): ExtendedDescription {
  const ariaLabel = target.getAttribute("aria-label")?.trim() || null;

  if (target.tagName.toLowerCase() === "a") {
    const href = anchorHREF(target, baseURI);
    if (href) {
      return { href, title: ariaLabel ?? extendedDescriptionTitle(target) };
    }
  }

  // Inline container (or unusable anchor): link to the target itself.
  return { href: resolveURL("#" + id, baseURI), title: ariaLabel };
}

/**
 * Resolves the anchor's `href` attribute against the base URI, or returns
 * null when the anchor cannot be used as a link target: no `href`, an empty
 * one, a bare `#`, or a scheme other than `http(s)` (`mailto:`,
 * `javascript:`, …).
 *
 * Only the `href` attribute is read: an SVG `<a>` carrying only `xlink:href`
 * is treated as an inline container (documented divergence).
 */
function anchorHREF(target: Element, baseURI: string): string | null {
  const href = target.getAttribute("href");
  if (!href || href === "#") {
    return null;
  }
  // The scheme filter applies to the raw attribute value: a relative href
  // resolved against the base URI keeps whatever scheme the base has.
  const scheme = /^[a-zA-Z][a-zA-Z0-9+.-]*:/.exec(href)?.[0];
  if (scheme) {
    return scheme === "http:" || scheme === "https:" ? href : null;
  }
  return resolveURL(href, baseURI);
}

/** Resolves `href` against `baseURI`, falling back to the raw value. */
function resolveURL(href: string, baseURI: string): string {
  try {
    return new URL(href, baseURI).href;
  } catch {
    return href;
  }
}

/**
 * Text-content title of an `<a>` extended description target: text nodes
 * contribute their raw text, `img` elements their `alt` attribute, joined
 * with a single space and whitespace-normalized.
 */
function extendedDescriptionTitle(target: Element): string | null {
  const parts: string[] = [];
  const visit = (node: Node) => {
    if (node.nodeType === Node.TEXT_NODE) {
      parts.push(node.nodeValue ?? "");
    } else if (node.nodeType === Node.ELEMENT_NODE) {
      const element = node as Element;
      if (element.tagName.toLowerCase() === "img") {
        parts.push(element.getAttribute("alt") ?? "");
      } else {
        element.childNodes.forEach(visit);
      }
    }
  };
  target.childNodes.forEach(visit);
  return parts.join(" ").replace(/\s+/g, " ").trim() || null;
}

/**
 * Resolves a space-separated list of element IDs and concatenates the
 * referenced elements' text alternatives (one-level approximation: each
 * referenced element contributes its own `aria-label` when present, otherwise
 * its text content).
 */
function resolveIDReferences(
  element: Element,
  attribute: string
): string | null {
  const ids = element.getAttribute(attribute);
  if (!ids) {
    return null;
  }
  return (
    ids
      .split(/\s+/)
      .filter((id) => id.length > 0)
      .map((id) => element.ownerDocument.getElementById(id) as Element | null)
      .filter((el): el is Element => el != null)
      .map(
        (el) =>
          el.getAttribute("aria-label")?.trim() ||
          el.textContent?.replace(/\s+/g, " ").trim() ||
          ""
      )
      .filter((text) => text.length > 0)
      .join(" ") || null
  );
}

function firstDirectChildText(element: Element, tag: string): string | null {
  const child = element.querySelector(`:scope > ${tag}`);
  return child?.textContent?.replace(/\s+/g, " ").trim() || null;
}

/**
 * Returns the text of the enclosing `<figure>`'s direct `<figcaption>` child,
 * if any. Also used by gestures.js for the `caption` payload field.
 *
 * An element living inside the figcaption (a publisher logo, a footnote
 * marker) is not captioned by the text wrapping it, so it gets no caption at
 * all rather than falling back to an outer figure.
 *
 * An extended description wrapped by the figcaption is excluded from the
 * caption: any `<details>` subtree, and any subtree rooted at an element the
 * element points at with `aria-details` or `aria-describedby`. Publishers do
 * put the description inside the caption, and a reading app displaying the
 * caption would otherwise print the whole long description — including one
 * hidden by CSS, which a sighted reader never sees.
 *
 * The exclusion deliberately does NOT apply to the accessible name computed by
 * `figureCaptionAsName()`: HTML-AAM 4.1.10 names the image from the whole
 * figcaption.
 */
export function findFigureCaption(element: Element): string | null {
  const figcaption = element
    .closest("figure")
    ?.querySelector(":scope > figcaption");
  if (!figcaption || figcaption.contains(element)) {
    return null;
  }

  const excludedIDs = (
    (element.getAttribute("aria-details") ?? "") +
    " " +
    (element.getAttribute("aria-describedby") ?? "")
  )
    .split(/\s+/)
    .filter((id) => id.length > 0);

  // `getAttribute("id")` rather than `.id`, because this helper also runs on
  // SVG elements.
  if (excludedIDs.includes(figcaption.getAttribute("id") ?? "")) {
    // The figcaption *is* the description: there is nothing left to display.
    return null;
  }

  const isExcluded = (candidate: Element) =>
    candidate.tagName.toLowerCase() === "details" ||
    excludedIDs.includes(candidate.getAttribute("id") ?? "");

  const clone = figcaption.cloneNode(true) as Element;
  const descendants = clone.querySelectorAll("*");
  for (let i = 0; i < descendants.length; i++) {
    if (isExcluded(descendants[i])) {
      descendants[i].remove();
    }
  }
  return clone.textContent?.replace(/\s+/g, " ").trim() || null;
}

/**
 * HTML-AAM 4.1.10 step 4, approximated: the figcaption names the image only
 * when the figure holds no other non-whitespace flow content — checked as
 * "the figure's normalized text equals the figcaption's, and the figure
 * contains no other embedded content".
 * https://www.w3.org/TR/html-aam-1.0/#img-element-accessible-name-computation
 */
function figureCaptionAsName(element: Element): string | null {
  const figure = element.closest("figure");
  const figcaption = figure?.querySelector(":scope > figcaption");
  if (!figure || !figcaption) {
    return null;
  }
  const normalize = (text: string | null) =>
    text?.replace(/\s+/g, " ").trim() ?? "";
  if (normalize(figure.textContent) !== normalize(figcaption.textContent)) {
    return null;
  }
  const embedded = figure.querySelectorAll(
    "img, svg, audio, video, object, iframe, embed"
  );
  for (let i = 0; i < embedded.length; i++) {
    if (embedded[i] !== element) {
      return null;
    }
  }
  return normalize(figcaption.textContent) || null;
}
