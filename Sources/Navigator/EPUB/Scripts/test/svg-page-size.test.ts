//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

/**
 * Tests the page size of the SVG documents rendered as fixed-layout pages.
 */

import { isSVGDocument, parseSVGPageSize } from "../src/svg-page-size";

/** Parses an SVG document whose root has the given attributes. */
function svg(attributes: string): Document {
  return new DOMParser().parseFromString(
    `<svg xmlns="http://www.w3.org/2000/svg" ${attributes}></svg>`,
    "image/svg+xml"
  );
}

describe("isSVGDocument", () => {
  it("returns true for an SVG document", () => {
    expect(isSVGDocument(svg(""))).toBe(true);
  });

  it("returns false for an HTML document containing an SVG", () => {
    const html = new DOMParser().parseFromString(
      '<html xmlns="http://www.w3.org/1999/xhtml"><body><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 800"/></body></html>',
      "application/xhtml+xml"
    );
    expect(isSVGDocument(html)).toBe(false);
  });
});

describe("parseSVGPageSize", () => {
  it.each([
    ['viewBox="0 0 600 800"', 600, 800],
    ['viewBox=" 10,20, 600.5 , 8e2 "', 600.5, 800],
    ['width="300" height="400"', 300, 400],
    ['width=" 300px " height="4e2PX"', 300, 400],
    ['width="6in" height="8in"', 576, 768],
    ['width="2.54cm" height="5.08cm"', 96, 192],
    ['width="25.4mm" height="50.8mm"', 96, 192],
    ['width="101.6q" height="203.2Q"', 96, 192],
    ['width="450pt" height="600pt"', 600, 800],
    ['width="6pc" height="12pc"', 96, 192],
  ])("returns the size of <svg %s>", (attributes, width, height) => {
    const size = parseSVGPageSize(svg(attributes));
    expect(size?.width).toBeCloseTo(width);
    expect(size?.height).toBeCloseTo(height);
  });

  it("prefers the viewBox to the width and height", () => {
    expect(
      parseSVGPageSize(svg('viewBox="0 0 600 800" width="300" height="400"'))
    ).toEqual({ width: 600, height: 800 });
  });

  it("falls back on the width and height with an invalid viewBox", () => {
    expect(
      parseSVGPageSize(svg('viewBox="0 0 0 800" width="300" height="400"'))
    ).toEqual({ width: 300, height: 400 });
  });

  it.each([
    "",
    'viewBox="0 0 600"',
    'viewBox="0 0 -600 800"',
    'viewBox="0 0 0x258 0x320"',
    'width="100%" height="100%"',
    'width="30em" height="40em"',
    'width="300 px" height="400 px"',
    'width="0x12c" height="0x190"',
    'width="1e999" height="400"',
    'width="-300" height="400"',
    'width="300"',
  ])("returns null for <svg %s>", (attributes) => {
    expect(parseSVGPageSize(svg(attributes))).toBeNull();
  });
});
