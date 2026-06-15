//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import { isScrollModeEnabled } from "./utils";
import { getCssSelector } from "css-selector-generator";

/**
 * Walks from `element` up through its parent chain, looking for the first
 * parent that is considered "user interactive" (self or ancestor).
 *
 * @param {Element|null} element
 * @returns {string|null} The `outerHTML` of the interactive element, or `null`
 *   when none is found. Despite the name, this does not return a DOM node.
 *
 * @see https://github.com/JayPanoz/architecture/tree/touch-handling/misc/touch-handling
 */
export function findNearestInteractiveElement(element) {
  if (element == null) {
    return null;
  }

  var interactiveTags = [
    "a",
    "audio",
    "button",
    "canvas",
    "details",
    "input",
    "label",
    "option",
    "select",
    "submit",
    "textarea",
    "video",
  ];
  if (interactiveTags.indexOf(element.nodeName.toLowerCase()) !== -1) {
    return element.outerHTML;
  }

  // Checks whether the element is editable by the user.
  if (
    element.hasAttribute("contenteditable") &&
    element.getAttribute("contenteditable").toLowerCase() != "false"
  ) {
    return element.outerHTML;
  }

  // Checks parents recursively because the touch might be for example on an <em> inside a <a>.
  if (element.parentElement) {
    return findNearestInteractiveElement(element.parentElement);
  }

  return null;
}

/**
 * Walks from `element` up through its parent chain, looking for the nearest
 * <img> or <picture> (self or ancestor).
 *
 * @param {Element|null} element
 * @returns {Element|null} The matched image element, or `null` when none is
 *   found or when the tap is on or inside an interactive element.
 */
export function findNearestImageElement(element) {
  if (element == null) {
    return null;
  }

  if (findNearestInteractiveElement(element) != null) {
    return null;
  }

  let current = element;
  while (current != null) {
    const tag = current.nodeName.toLowerCase();
    if (tag === "img" || tag === "picture") {
      return current;
    }
    current = current.parentElement;
  }

  return null;
}

function parseSrcset(srcset) {
  return srcset.split(",").map((part) => {
    const trimmed = part.trim();
    const spaceIndex = trimmed.lastIndexOf(" ");
    if (spaceIndex === -1) {
      return { url: trimmed, width: null };
    }
    const descriptor = trimmed.slice(spaceIndex + 1).trim();
    const width = descriptor.endsWith("w")
      ? parseInt(descriptor, 10)
      : null;
    return { url: trimmed.slice(0, spaceIndex).trim(), width: width };
  });
}

function pickBestFromSrcset(srcset) {
  const targetWidth = window.innerWidth * window.devicePixelRatio;
  const candidates = parseSrcset(srcset);
  let best = null;
  let bestWidth = -1;
  let largest = null;
  let largestWidth = -1;

  for (const candidate of candidates) {
    if (candidate.width != null) {
      if (candidate.width > largestWidth) {
        largestWidth = candidate.width;
        largest = candidate.url;
      }
      if (candidate.width <= targetWidth && candidate.width > bestWidth) {
        bestWidth = candidate.width;
        best = candidate.url;
      }
    } else if (best == null && largest == null) {
      best = candidate.url;
    }
  }

  return best || largest || (candidates.length > 0 ? candidates[0].url : null);
}

/**
 * Resolves the best matching href for a <picture> element.
 */
export function resolvePictureHref(pictureElement) {
  const sources = pictureElement.querySelectorAll("source");
  for (const source of sources) {
    const media = source.getAttribute("media");
    if (media && !window.matchMedia(media).matches) {
      continue;
    }

    const srcset = source.getAttribute("srcset");
    if (srcset) {
      const url = pickBestFromSrcset(srcset);
      if (url) {
        return url;
      }
    }

    const src = source.getAttribute("src");
    if (src) {
      return src;
    }
  }

  const img = pictureElement.querySelector("img");
  if (img) {
    return img.currentSrc || img.getAttribute("src");
  }

  return null;
}

/**
 * @param {Element} imageElement
 * @returns {string|null} Trimmed text content of the enclosing <figcaption>,
 *   or `null` when no figure/figcaption is found.
 */
export function findFigcaptionText(imageElement) {
  const figure = imageElement.closest("figure");
  if (!figure) {
    return null;
  }
  const caption = figure.querySelector("figcaption");
  return caption ? caption.textContent.trim() : null;
}

/**
 * Builds the structured tap target metadata for an image element.
 *
 * @param {Element} imageElement An <img> or <picture> element.
 * @returns {{ type: "image", href: string, caption: string|null }|null}
 *   Partial tap target payload (`type`, `href`, `caption`). Does not include
 *   `frame`; the caller is responsible for adding it before sending to native.
 */
export function buildImageTapTarget(imageElement) {
  const tag = imageElement.nodeName.toLowerCase();
  let rectElement = imageElement;
  let href = null;
  let caption = null;

  if (tag === "picture") {
    href = resolvePictureHref(imageElement);
    const img = imageElement.querySelector("img");
    if (img) {
      rectElement = img;
      caption = img.alt || findFigcaptionText(imageElement) || null;
    }
  } else {
    href = imageElement.currentSrc || imageElement.getAttribute("src");
    caption = imageElement.alt || findFigcaptionText(imageElement) || null;
  }

  if (!href) {
    return null;
  }

  return {
    type: "image",
    href: href,
    caption: caption || null,
  };
}

/// Returns the `Locator` object to the first block element that is visible on
/// the screen.
export function findFirstVisibleLocator() {
  const element = findElement(document.body);
  return {
    href: "#",
    type: "application/xhtml+xml",
    locations: {
      cssSelector: getCssSelector(element),
    },
    text: {
      highlight: element.textContent,
    },
  };
}

function findElement(rootElement) {
  for (var i = 0; i < rootElement.children.length; i++) {
    const child = rootElement.children[i];
    if (!shouldIgnoreElement(child) && isElementVisible(child)) {
      return findElement(child);
    }
  }
  return rootElement;
}

function isElementVisible(element) {
  if (readium.isFixedLayout) return true;

  if (element === document.body || element === document.documentElement) {
    return true;
  }
  if (!document || !document.documentElement || !document.body) {
    return false;
  }

  const rect = element.getBoundingClientRect();
  if (isScrollModeEnabled()) {
    return rect.bottom > 0 && rect.top < window.innerHeight;
  } else {
    return rect.right > 0 && rect.left < window.innerWidth;
  }
}

function shouldIgnoreElement(element) {
  const elStyle = getComputedStyle(element);
  if (elStyle) {
    const display = elStyle.getPropertyValue("display");
    if (display != "block") {
      return true;
    }
    // Cannot be relied upon, because web browser engine reports invisible when out of view in
    // scrolled columns!
    // const visibility = elStyle.getPropertyValue("visibility");
    // if (visibility === "hidden") {
    //     return false;
    // }
    const opacity = elStyle.getPropertyValue("opacity");
    if (opacity === "0") {
      return true;
    }
  }

  return false;
}
