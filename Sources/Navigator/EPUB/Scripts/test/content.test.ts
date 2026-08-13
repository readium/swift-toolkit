//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

/**
 * Tests the extraction of the element targeted by a gesture, and in
 * particular the detection of `<svg>` elements wrapping a single bitmap,
 * whose Swift counterpart lives in `HTMLResourceContentIterator`.
 */

import {
  extractTargetElement,
  findImageHref,
  findWrappedImage,
  Frame,
} from "../src/content";

/** Parses the given markup and returns its first element. */
function parse(markup: string): Element {
  const document = new DOMParser().parseFromString(
    `<html xmlns="http://www.w3.org/1999/xhtml"><body>${markup}</body></html>`,
    "application/xhtml+xml"
  );
  const element = document.body.firstElementChild;
  if (!element) {
    throw new Error(`No element found in ${markup}`);
  }
  return element;
}

/**
 * Renders the given markup in the test document and returns its root.
 *
 * Unlike `parse`, this goes through the HTML parser, which leaves the legacy
 * `xlink:href` attribute without a namespace.
 */
function render(markup: string): Element {
  document.body.innerHTML = markup;
  const element = document.body.firstElementChild;
  if (!element) {
    throw new Error(`No element found in ${markup}`);
  }
  return element;
}

/** Returns the URL of the bitmap wrapped by the given markup, if any. */
function wrappedImageHref(markup: string): string | null {
  const image = findWrappedImage(parse(markup));
  return image ? findImageHref(image) : null;
}

describe("findWrappedImage", () => {
  it("finds the bitmap of a cover wrapper", () => {
    expect(
      wrappedImageHref(`
        <svg xmlns="http://www.w3.org/2000/svg"
             xmlns:xlink="http://www.w3.org/1999/xlink"
             width="100%" height="100%" viewBox="0 0 656 1000"
             preserveAspectRatio="xMidYMid meet">
          <image width="656" height="1000" xlink:href="cover.jpg"/>
        </svg>
      `)
    ).toBe("cover.jpg");
  });

  it("ignores elements which don't draw anything", () => {
    expect(
      wrappedImageHref(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <title>Cover</title>
          <desc>The book cover</desc>
          <metadata/>
          <defs><linearGradient id="gradient"/></defs>
          <style>image { opacity: 1 }</style>
          <image href="cover.jpg"/>
        </svg>
      `)
    ).toBe("cover.jpg");
  });

  it("returns null for an SVG drawing its own content", () => {
    expect(
      findWrappedImage(
        parse(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <image href="cover.jpg"/>
          <rect width="10" height="10"/>
        </svg>
      `)
      )
    ).toBeNull();
  });

  it("returns null for an SVG with several images", () => {
    expect(
      findWrappedImage(
        parse(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <image href="left.jpg"/>
          <image href="right.jpg"/>
        </svg>
      `)
      )
    ).toBeNull();
  });

  it("returns null for a nested image, which carries its own transform", () => {
    expect(
      findWrappedImage(
        parse(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <g transform="rotate(45)"><image href="cover.jpg"/></g>
        </svg>
      `)
      )
    ).toBeNull();
  });

  it.each(["transform", "clip-path", "mask", "filter", "opacity"])(
    "returns null for an image drawn through %s",
    (attribute) => {
      expect(
        findWrappedImage(
          parse(`
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
            <image href="cover.jpg" ${attribute}="whatever"/>
          </svg>
        `)
        )
      ).toBeNull();
    }
  );

  it("returns null for an empty SVG", () => {
    expect(
      findWrappedImage(
        parse(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"/>`)
      )
    ).toBeNull();
  });

  it("returns null for a non-SVG element", () => {
    expect(findWrappedImage(parse(`<img src="cover.jpg"/>`))).toBeNull();
  });
});

describe("findImageHref", () => {
  /** Returns the URL pointed to by the `<image>` of the given `<svg>`. */
  function imageHref(svg: Element): string | null {
    const image = svg.querySelector("image");
    if (!image) {
      throw new Error(`No image found in ${svg.outerHTML}`);
    }
    return findImageHref(image);
  }

  it("reads the SVG 2 href attribute", () => {
    expect(
      imageHref(
        parse(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <image href="cover.jpg"/>
        </svg>
      `)
      )
    ).toBe("cover.jpg");
  });

  it("reads the legacy href under any prefix", () => {
    expect(
      imageHref(
        parse(`
        <svg xmlns="http://www.w3.org/2000/svg"
             xmlns:xl="http://www.w3.org/1999/xlink" viewBox="0 0 100 100">
          <image xl:href="cover.jpg"/>
        </svg>
      `)
      )
    ).toBe("cover.jpg");
  });

  it("reads the legacy href of a document parsed without namespaces", () => {
    expect(
      imageHref(
        render(
          `<svg viewBox="0 0 100 100"><image xlink:href="cover.jpg"/></svg>`
        )
      )
    ).toBe("cover.jpg");
  });

  it("prefers the SVG 2 href attribute over the legacy one", () => {
    expect(
      imageHref(
        parse(`
        <svg xmlns="http://www.w3.org/2000/svg"
             xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 100 100">
          <image href="cover.jpg" xlink:href="legacy.jpg"/>
        </svg>
      `)
      )
    ).toBe("cover.jpg");
  });

  it("returns null when the image points nowhere", () => {
    expect(
      imageHref(
        parse(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <image width="100" height="100"/>
        </svg>
      `)
      )
    ).toBeNull();
  });
});

describe("extractTargetElement", () => {
  beforeAll(() => {
    // jsdom doesn't implement `CSS.escape`, which the CSS selector generator
    // calls. The generated selectors are not under test here.
    (globalThis as { CSS?: unknown }).CSS ??= {
      escape: (value: string) => value,
    };
  });

  afterEach(() => {
    delete window.readium;
  });

  /** jsdom has no layout, so the boxes are given to the elements. */
  function stubFrame(element: Element, frame: Frame) {
    element.getBoundingClientRect = () =>
      ({
        ...frame,
        left: frame.x,
        top: frame.y,
        right: frame.x + frame.width,
        bottom: frame.y + frame.height,
        toJSON: () => ({}),
      } as DOMRect);
  }

  /** Absolute form of a URL relative to the test document. */
  function absolute(href: string): string {
    return new URL(href, document.baseURI).href;
  }

  it("returns null when there is no target", () => {
    expect(extractTargetElement(null)).toBeNull();
  });

  it("returns null when the gesture doesn't land on an image", () => {
    const element = render(`<p>Not an image</p>`);
    expect(extractTargetElement(element)).toBeNull();
  });

  it("reports the resource containing the element", () => {
    window.readium = { link: { href: "EPUB/chapter1.xhtml" } };
    const element = render(`<img src="cover.jpg"/>`);

    expect(extractTargetElement(element)?.resourceHref).toBe(
      "EPUB/chapter1.xhtml"
    );
  });

  it("reports no resource outside of a Readium context", () => {
    const element = render(`<img src="cover.jpg"/>`);
    expect(extractTargetElement(element)?.resourceHref).toBeNull();
  });

  it("extracts an image element", () => {
    const element = render(`<img src="cover.jpg" alt="Cover"/>`);

    const target = extractTargetElement(element);
    expect(target?.tag).toBe("img");
    expect(target?.src).toBe(absolute("cover.jpg"));
    expect(target?.html).toBeNull();
    expect(target?.accessibleName).toBe("Cover");
  });

  it("extracts the bitmap of a cover wrapper tapped on its inner image", () => {
    const svg = render(`
      <svg viewBox="0 0 656 1000"><image xlink:href="cover.jpg"/></svg>
    `);
    const image = svg.querySelector("image")!;

    const target = extractTargetElement(image);
    expect(target?.tag).toBe("svg");
    expect(target?.src).toBe(absolute("cover.jpg"));
    expect(target?.html).toBeNull();
  });

  it("extracts a richer SVG as markup", () => {
    const element = render(`<svg viewBox="0 0 100 100"><circle/></svg>`);

    const target = extractTargetElement(element);
    expect(target?.tag).toBe("svg");
    expect(target?.src).toBeNull();
    expect(target?.html).toContain("<circle");
  });

  it("extracts a wrapper pointing nowhere as markup", () => {
    const element = render(`<svg viewBox="0 0 100 100"><image/></svg>`);

    const target = extractTargetElement(element);
    expect(target?.src).toBeNull();
    expect(target?.html).toContain("<image");
  });

  it("reports the frame of the bitmap drawn by a wrapper", () => {
    const svg = render(
      `<svg viewBox="0 0 656 1000"><image xlink:href="cover.jpg"/></svg>`
    );
    stubFrame(svg, { x: 0, y: 0, width: 400, height: 1000 });
    const drawn = { x: 72, y: 0, width: 256, height: 390 };
    stubFrame(svg.querySelector("image")!, drawn);

    expect(extractTargetElement(svg)?.frame).toEqual(drawn);
  });

  it("falls back to the SVG frame when the bitmap has no box of its own", () => {
    const svg = render(
      `<svg viewBox="0 0 656 1000"><image xlink:href="cover.jpg"/></svg>`
    );
    const box = { x: 0, y: 0, width: 400, height: 1000 };
    stubFrame(svg, box);
    stubFrame(svg.querySelector("image")!, { x: 0, y: 0, width: 0, height: 0 });

    expect(extractTargetElement(svg)?.frame).toEqual(box);
  });
});
