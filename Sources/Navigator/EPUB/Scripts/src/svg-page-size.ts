//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

interface Size {
  width: number;
  height: number;
}

/** Returns whether the given `document` is an SVG document. */
export function isSVGDocument(document: Document): boolean {
  const root = document.documentElement;
  return (
    !!root &&
    root.namespaceURI === "http://www.w3.org/2000/svg" &&
    root.localName === "svg"
  );
}

/**
 * Parses the page size of an SVG document from its root element.
 *
 * The `viewBox` of a fixed-layout SVG document defines its initial containing
 * block (EPUB 3.3). As a fallback, the `width` and `height` attributes are
 * used when they are absolute lengths.
 *
 * Returns `null` if the size can't be determined.
 */
export function parseSVGPageSize(document: Document): Size | null {
  const root = document.documentElement;
  return (
    parseViewBox(root.getAttribute("viewBox")) ??
    validSize(
      parseAbsoluteLength(root.getAttribute("width")),
      parseAbsoluteLength(root.getAttribute("height"))
    )
  );
}

/** Parses the size of a `viewBox="min-x min-y width height"` attribute. */
function parseViewBox(viewBox: string | null): Size | null {
  const values = (viewBox ?? "").trim().split(/[\s,]+/);
  if (values.length !== 4) {
    return null;
  }
  return validSize(parseNumber(values[2]), parseNumber(values[3]));
}

/** Number of CSS pixels in each absolute unit. */
const pixelsPerUnit = new Map<string, number>([
  ["", 1],
  ["px", 1],
  ["in", 96],
  ["cm", 96 / 2.54],
  ["mm", 96 / 25.4],
  ["q", 96 / 101.6],
  ["pt", 96 / 72],
  ["pc", 96 / 6],
]);

/**
 * Parses an absolute length in CSS pixels, ignoring the relative units such
 * as `%` or `em`.
 */
function parseAbsoluteLength(length: string | null): number | null {
  const match = /^\s*(.*?)([a-z]*)\s*$/i.exec(length ?? "");
  const ratio = match && pixelsPerUnit.get(match[2].toLowerCase());
  const number = match && parseNumber(match[1]);
  return ratio && number !== null ? number * ratio : null;
}

/** Parses a finite decimal number, in the SVG syntax. */
function parseNumber(value: string): number | null {
  if (!/^[+-]?[0-9]*\.?[0-9]+(e[+-]?[0-9]+)?$/i.test(value)) {
    return null;
  }
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function validSize(width: number | null, height: number | null): Size | null {
  return width && height && width > 0 && height > 0 ? { width, height } : null;
}
