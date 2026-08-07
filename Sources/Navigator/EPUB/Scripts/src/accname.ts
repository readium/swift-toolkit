//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

/**
 * Accessible name and description of an HTML element, computed following a
 * pragmatic subset of https://www.w3.org/TR/accname-1.2
 *
 * This is the TypeScript counterpart of the Swift implementation in
 * `Sources/Shared/Publication/Services/Content/Iterators/HTMLAccessibilityProperties.swift`
 * — both MUST implement exactly the same subset. What keeps them in lockstep is
 * the shared case manifest in `scripts/accname-sample/cases.toml`: it generates
 * the fixtures both test suites run against, so a rule is stated once and
 * asserted twice. Add cases there.
 *
 * Implemented:
 * - Source precedence for the name: `aria-labelledby` → `aria-label` →
 *   host-language sources → `title`.
 * - Element-level suppression: `aria-hidden="true"`, or a presentational
 *   `role` not cancelled by a global ARIA attribute, yields no name and no
 *   description.
 * - The description cascade (`aria-describedby` → `aria-description` →
 *   host-language sources → unused `title`) stops at the first PRESENT
 *   markup, even if it resolves to an empty description.
 * - HTML-AAM 4.1.10 rules for `img`: an empty `alt` attribute marks a
 *   decorative image and blocks the `title` fallback (HTML-AAM overriding
 *   literal accname-1.2, whose step 2.9 would still name the image from the
 *   tooltip; browsers follow HTML-AAM); a figcaption names an image which has
 *   no `alt`/`title` attribute and no sibling content.
 *
 * Deliberately skipped / divergences:
 * - Full recursive traversal of `aria-labelledby`/`aria-describedby` targets;
 *   we approximate one level: each target contributes its own `aria-label`
 *   when present, else its text content. Nested images' `alt`, chained
 *   labelledby and embedded form-control values do not contribute.
 * - Hidden-element rules beyond the element itself: hidden ancestors, and the
 *   exclusion of hidden nodes inside referenced targets (kept out of the DOM
 *   side for parity with the Swift implementation, which has no CSS
 *   knowledge).
 * - Roles that prohibit naming other than `presentation`/`none`; the
 *   presentational-role conflict rule is narrowed to the four ARIA attributes
 *   this helper reads (spec: any global ARIA attribute or focusable element);
 *   unknown role tokens are not validated (the first token wins).
 * - CSS generated content (`::before`/`::after`) and name-from-content.
 * - An `aria-describedby` whose IDREFs all dangle still counts as "the first
 *   relevant markup found" and stops the description cascade (attribute
 *   presence = found). The spec doesn't spell this out and browsers vary;
 *   declared as a choice.
 * - HTML-AAM's figcaption-as-name fallback approximates the "no other
 *   non-whitespace flow content descendants" condition: the figure's
 *   normalized text must equal the figcaption's, and the figure must contain
 *   no other embedded content.
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
}

/**
 * Computes the accessible name and description of an element, following a
 * pragmatic subset of https://www.w3.org/TR/accname-1.2
 */
export function computeAccessibilityProperties(
  element: Element
): AccessibilityProperties {
  const tag = element.tagName.toLowerCase();
  const title = element.getAttribute("title")?.trim() || null;

  // Step 0: element-level suppression (accname steps 1 and 2A).
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
    element.hasAttribute("aria-description");
  if (
    element.getAttribute("aria-hidden")?.toLowerCase() === "true" ||
    ((firstRole === "presentation" || firstRole === "none") &&
      !hasGlobalARIAAttribute)
  ) {
    return { name: null, description: null };
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

  return { name, description };
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
      .map((id) => element.ownerDocument.getElementById(id))
      .filter((el): el is HTMLElement => el != null)
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
 */
export function findFigureCaption(element: Element): string | null {
  const figcaption = element
    .closest("figure")
    ?.querySelector(":scope > figcaption");
  return figcaption?.textContent?.replace(/\s+/g, " ").trim() || null;
}

/**
 * HTML-AAM 4.1.10 step 4, approximated: the figcaption names the image only
 * when the figure holds no other non-whitespace flow content — checked as
 * "the figure's normalized text equals the figcaption's, and the figure
 * contains no other embedded content".
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
