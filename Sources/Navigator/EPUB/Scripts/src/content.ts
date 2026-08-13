//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import { getCssSelector } from "css-selector-generator";
import {
  computeAccessibilityProperties,
  findFigureCaption,
  ExtendedDescription,
} from "./accessibility-properties";

declare global {
  interface Window {
    readium?: { link?: { href?: string } };
  }
}

/** Bounding rectangle of an element, in the coordinates of its own document. */
export interface Frame {
  x: number;
  y: number;
  width: number;
  height: number;
}

/**
 * Metadata about the element targeted by a gesture, from which the Swift side
 * builds the appropriate `ContentElement`.
 */
export interface TargetElement {
  /** Name of the element's tag, lowercased. */
  tag: string;
  /** Raw markup, only for an inline SVG which has no resolvable `src`. */
  html: string | null;
  /** Absolute URL of the image the element points to, if any. */
  src: string | null;
  /** HREF of the resource containing the element. */
  resourceHref: string | null;
  /**
   * Frame of the drawn image, in the coordinates of its own document. A
   * caller showing the resource in a viewport of its own (e.g. a fixed layout
   * spread) is responsible for adjusting it.
   */
  frame: Frame;
  accessibleName: string | null;
  accessibleDescription: string | null;
  extendedDescriptions: ExtendedDescription[];
  /** Text of the enclosing figure's `figcaption`. */
  caption: string | null;
  cssSelector: string | null;
}

/**
 * Extracts metadata about the image targeted by a gesture, or null when the
 * gesture doesn't land on one.
 */
export function extractTargetElement(
  element: Element | null
): TargetElement | null {
  if (!element || !element.getBoundingClientRect) {
    return null;
  }

  const imageElement = findNearestImageElement(element);
  if (!imageElement) {
    return null;
  }

  let rawSrc =
    imageElement.getAttribute("src") || imageElement.getAttribute("href");

  // An `<svg>` wrapping a single `<image>` carries the bitmap URL on the
  // inner element. Reading it there yields a plain image element instead of
  // an inline SVG, whose relative references would not resolve outside of
  // the publication document.
  let wrappedImage = rawSrc ? null : findWrappedImage(imageElement);
  const wrappedSrc = wrappedImage ? findImageHref(wrappedImage) : null;
  if (wrappedSrc) {
    rawSrc = wrappedSrc;
  } else {
    // The wrapper points nowhere, so it is reported as inline SVG after all.
    wrappedImage = null;
  }

  // The frame is the drawn bitmap's own, which in a wrapper is smaller than
  // the `<svg>` box whenever `preserveAspectRatio` letterboxes it. An image
  // without a box of its own falls back to the `<svg>`.
  let rect = (wrappedImage ?? imageElement).getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) {
    rect = imageElement.getBoundingClientRect();
  }

  // Resolve the raw src/href attribute to an absolute URL using the document's
  // base URI. `getAttribute` returns the literal attribute value (possibly
  // relative), while we need the absolute form so Swift can relativize it
  // against the publication base URL to recover the correct manifest href.
  const src = rawSrc ? new URL(rawSrc, document.baseURI).href : null;

  const accessibility = computeAccessibilityProperties(imageElement);

  return {
    tag: imageElement.tagName.toLowerCase(),
    // `html` is only needed for inline SVGs that have no resolvable `src`.
    html: src ? null : imageElement.outerHTML,
    src: src,
    resourceHref: window.readium?.link?.href ?? null,
    frame: {
      x: rect.left,
      y: rect.top,
      width: rect.width,
      height: rect.height,
    },
    accessibleName: accessibility.name,
    accessibleDescription: accessibility.description,
    extendedDescriptions: accessibility.extendedDescriptions,
    caption: findFigureCaption(imageElement),
    cssSelector: getCssSelector(imageElement),
  };
}

/**
 * Walks up the DOM tree from the given element to find the nearest image
 * element (img, svg).
 */
function findNearestImageElement(element: Element): Element | null {
  const imageTags = ["img", "svg"];
  let current: Element | null = element;
  while (current && current !== document.documentElement) {
    if (imageTags.includes(current.tagName.toLowerCase())) {
      return current;
    }
    current = current.parentElement;
  }
  return null;
}

/** Namespace of the legacy `xlink:href` attribute, used by SVG 1.1. */
const XLINK_NAMESPACE = "http://www.w3.org/1999/xlink";

/**
 * Elements which don't draw anything by themselves, and therefore don't
 * prevent an `<svg>` from being a wrapper around a single bitmap.
 */
const NON_RENDERING_TAGS = ["title", "desc", "metadata", "defs", "style"];

/**
 * Attributes changing the way an `<image>` is drawn, which the bitmap on its
 * own cannot reproduce.
 */
const RENDERING_ATTRIBUTES = [
  "transform",
  "clip-path",
  "mask",
  "filter",
  "opacity",
];

/**
 * Returns the single `<image>` drawn by an `<svg>` wrapping a bitmap, as
 * generated by some EPUB toolchains for cover pages.
 *
 * Returns null for anything else, in particular a richer SVG, which is a
 * drawing of its own rather than a wrapper and must be handled as inline SVG
 * markup.
 *
 * The Swift counterpart is `wrappedImageHREFRelativeToHREF` in
 * `Sources/Shared/Publication/Services/Content/Iterators/HTMLResourceContentIterator.swift`,
 * which must recognize the same wrappers, so that a tapped cover and the same
 * cover reached through the content iterator yield the same element.
 */
export function findWrappedImage(element: Element): Element | null {
  if (element.tagName.toLowerCase() !== "svg") {
    return null;
  }

  let found: Element | null = null;
  for (const child of Array.from(element.children)) {
    const tag = child.tagName.toLowerCase();
    if (NON_RENDERING_TAGS.includes(tag)) {
      continue;
    }
    if (tag !== "image" || found) {
      return null;
    }
    found = child;
  }
  if (!found) {
    return null;
  }

  const image = found;
  if (RENDERING_ATTRIBUTES.some((name) => image.hasAttribute(name))) {
    return null;
  }
  return image;
}

/**
 * Returns the raw URL an SVG `<image>` points to, from either the SVG 2 or
 * the SVG 1.1 attribute.
 *
 * The literal `xlink:href` is the last resort, for a document parsed without
 * namespace support.
 */
export function findImageHref(image: Element): string | null {
  return (
    image.getAttribute("href") ||
    image.getAttributeNS(XLINK_NAMESPACE, "href") ||
    image.getAttribute("xlink:href") ||
    null
  );
}
