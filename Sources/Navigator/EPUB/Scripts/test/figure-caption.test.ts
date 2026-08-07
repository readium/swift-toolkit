//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

/**
 * Tests for `findFigureCaption` (`accname.ts`), which feeds the `caption`
 * field of the pointer-event payload.
 *
 * The accessible name and description computation is covered by
 * `accname-sample.test.ts`, which runs the shared case manifest in
 * `scripts/accname-sample/cases.toml` — the same one the Swift suite in
 * `Tests/SharedTests/Publication/Services/Content/Iterators/AccnameSampleTests.swift`
 * asserts against. Add cases there, not here.
 */

import { findFigureCaption } from "../src/accname";

describe("findFigureCaption", () => {
  test("imageInFigureGetsCaptionFromFigcaption", () => {
    document.body.innerHTML = `
      <figure><img src="a.jpg" alt="Alt text"/><figcaption>The caption</figcaption></figure>
    `;
    const element = document.body.querySelector("img")!;
    expect(findFigureCaption(element)).toBe("The caption");
  });

  test("nestedFigureUsesTheNearestFigcaption", () => {
    document.body.innerHTML = `
      <figure>
        <figure><img src="a.jpg" alt="Alt"/><figcaption>Inner</figcaption></figure>
        <figcaption>Outer</figcaption>
      </figure>
    `;
    const element = document.body.querySelector("img")!;
    expect(findFigureCaption(element)).toBe("Inner");
  });

  test("figcaptionNotFirstChildStillProvidesTheCaption", () => {
    document.body.innerHTML = `
      <figure><p>intro</p><img src="a.jpg" alt="Alt"/><figcaption>Cap</figcaption></figure>
    `;
    const element = document.body.querySelector("img")!;
    expect(findFigureCaption(element)).toBe("Cap");
  });

  test("elementOutsideAFigureHasNoCaption", () => {
    document.body.innerHTML = `<img src="a.jpg" alt="Alt"/>`;
    const element = document.body.querySelector("img")!;
    expect(findFigureCaption(element)).toBeNull();
  });
});
