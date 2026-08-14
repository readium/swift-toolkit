# Accessibility properties sample

This directory makes sure Readium computes the same accessibility properties in Swift and in TypeScript.

Content elements have four accessibility properties: an accessible name, a description, a caption and extended descriptions. Readium computes them twice, once in Swift (`HTMLAccessibilityProperties.swift`, in `ReadiumShared`) and once in TypeScript (`accessibility-properties.ts`, in the EPUB navigator). Both must give the same answer for the same HTML.

`cases.toml` is where those answers are written down: each case pairs a piece of HTML markup with the properties it must produce. `python3 generate.py` reads the file and writes:

- XHTML fixtures for the Swift test suite
- the same XHTML for the jest test suite
- `accessibility-properties.epub`, which you can open in a reader to check the same cases by hand

Both test suites come from the same file, so the two implementations stay in sync.

The two implementations follow a pragmatic subset of [accname-1.2](https://www.w3.org/TR/accname-1.2) and the [`aria-details` extended descriptions](https://daisy.github.io/transitiontoepub/best-practices/extended-desc/ExtendedDescriptionsBestPractices.html) best practices. [ADR 0001](../../../docs/adr/0001-pragmatic-accname-subset.md) records what the subset leaves out.

## Regenerating

```sh
python3 generate.py
```

It writes:

| Path                                                                                 | Contents                         |
|--------------------------------------------------------------------------------------|----------------------------------|
| `/Tests/SharedTests/Fixtures/Publication/Services/Content/accessibility-properties/` | XHTML, for the Swift suite       |
| `/Sources/Navigator/EPUB/Scripts/test/fixtures/accessibility-properties/`            | XHTML, for the jest suite        |
| `./accessibility-properties.epub`                                                    | the sample, openable in a reader |

The XHTML is written twice so that neither package reaches into the other's tree. Both copies come from `cases.toml`, so they cannot drift. Never edit the generated files: edit `cases.toml` and regenerate.

## Adding a case

Append a `[[resource.case]]` block to `cases.toml`. Absent `name`, `description` or `caption` means "expected none". The element under test is flagged with `data-subject=""`; the generator replaces that marker with `id`, `data-case` and the `data-expected-*` attributes, and leaves the rest of the markup verbatim.

Keys: `id`, `title`, `name`, `description`, `caption`, `extended_descriptions`, `note`, `divergence`, `skipped`, `markup`. Backticks in prose become `<code>`.

`caption` is the text displayed alongside the element, taken from the enclosing figure's `figcaption`. It is not part of accname, but it is computed by the same two files, so it is asserted here too.

Keep whitespace between block elements in the markup: SwiftSoup's `text()` inserts a space before a block element, while the DOM's `textContent` does not, so `<figcaption>Cap<details>…` diverges between the two implementations while `<figcaption>Cap\n  <details>…` does not.

`extended_descriptions` is an array of `{ href, title }` tables, with hrefs relative to the document; it is emitted as a JSON array in the `data-expected-extended-descriptions` attribute (JSON survives attribute escaping, unlike separator formats which break on real titles). An absent key means "expected none", so every case also asserts that no extended descriptions leak in.

## epubcheck

`generate.py` runs `epubcheck` when it is on the `PATH` and diffs its output against `epubcheck-baseline.txt`.

The sample cannot be entirely epubcheck-clean: several cases exist precisely to pin down what we do with markup that is *deliberately* malformed — dangling `aria-labelledby`/`aria-describedby` IDREFs, `aria-hidden="TRUE"`, uppercase and multi-token `role` values, and multi-token `aria-details` (an ARIA 1.3 IDREF list, which EPUB's ARIA 1.2 schema rejects). Dropping them would drop the behaviour the sample documents.

The baseline keeps the check meaningful: any message that is not already accounted for fails the run. After adding a case that is knowingly invalid, run `python3 generate.py --update-epubcheck-baseline`.

## Unit tests

- `/Tests/SharedTests/Publication/Services/Content/Iterators/AccessibilityPropertiesSampleTests.swift` runs each document through `HTMLResourceContentIterator` and matches every emitted element to its case through the `#case-<id>` CSS selector.
- `/Sources/Navigator/EPUB/Scripts/test/accessibility-properties-sample.test.ts` loads the fixtures into jsdom and runs `computeAccessibilityProperties` and `findFigureCaption` over every `[data-case]` element.

Both skip cases flagged `skipped = true`, which describe rules that are not implemented yet (all of `table.xhtml`). Removing those flags is the acceptance test for a future implementation.
