//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

/**
 * Parity test for the accname sample publication.
 *
 * The fixtures under `test/fixtures/accname/` are generated from
 * `/scripts/accname-sample/cases.toml`, which also drives the Swift end-to-end
 * suite.
 *
 * Every subject element carries the expected name and description as
 * `data-expected-*` attributes, so both harnesses assert against a single
 * source of truth.
 */

import * as fs from "fs";
import * as path from "path";
import { computeAccessibilityProperties } from "../src/accname";

const FIXTURES_DIR = path.join(__dirname, "fixtures/accname");

interface Case {
  document: string;
  id: string;
  element: Element;
  expectedName: string | null;
  expectedDescription: string | null;
}

/** Loads every non-skipped case of every generated fixture. */
function loadCases(): Case[] {
  const cases: Case[] = [];
  for (const filename of fs.readdirSync(FIXTURES_DIR).sort()) {
    if (!filename.endsWith(".xhtml")) {
      continue;
    }
    const source = fs.readFileSync(path.join(FIXTURES_DIR, filename), "utf-8");
    const body = /<body[^>]*>([\s\S]*)<\/body>/.exec(source);
    if (!body) {
      throw new Error(`${filename}: no <body> element`);
    }

    // Each fixture gets its own document so that IDREFs cannot resolve across
    // files, matching what the Swift side sees when it parses one resource at
    // a time.
    const doc = document.implementation.createHTMLDocument(filename);
    doc.body.innerHTML = body[1];

    for (const element of Array.from(
      doc.querySelectorAll("[data-case]:not([data-test-skipped])")
    )) {
      cases.push({
        document: filename,
        id: element.getAttribute("data-case")!,
        element,
        expectedName: element.getAttribute("data-expected-name"),
        expectedDescription: element.getAttribute("data-expected-description"),
      });
    }
  }
  return cases;
}

const CASES = loadCases();

describe("accname sample publication", () => {
  test("the fixtures hold cases", () => {
    expect(CASES.length).toBeGreaterThan(0);
  });

  test.each(CASES.map((c) => [`${c.document} · ${c.id}`, c] as const))(
    "%s",
    (_label, testCase) => {
      const result = computeAccessibilityProperties(testCase.element);
      expect(result.name).toBe(testCase.expectedName);
      expect(result.description).toBe(testCase.expectedDescription);
    }
  );
});
