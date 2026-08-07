# Accessible name & description sample

A small EPUB that doubles as a readable specification for the pragmatic [accname-1.2](https://www.w3.org/TR/accname-1.2) subset implemented in this repository:

- `HTMLAccessibilityProperties.swift` (SwiftSoup, feeds `ContentElement` attributes)
- `accname.ts` (DOM, feeds `PointerEvent.targetElement`)

Both must implement exactly the same subset. This sample is what keeps them
correct end to end: one section per case, stating the expected name and
description in prose, followed by the markup under test.

## Regenerating

```sh
python3 generate.py
```

It writes:

| Path | Contents |
| --- | --- |
| `/Tests/SharedTests/Fixtures/Publication/Services/Content/accname/` | XHTML, for the Swift suite |
| `/Sources/Navigator/EPUB/Scripts/test/fixtures/accname/` | XHTML, for the jest suite |
| `./accname.epub` | the sample, openable in a reader |

Only the XHTML is under test: the content iterator reads one resource at a time, so no container, manifest or media asset is involved, and the `src` attributes in the fixtures point at files that exist only inside the EPUB. The EPUB adds the packaging and the assets a reading system needs.

The XHTML is written twice so that neither package reaches into the other's tree. Both copies come from `cases.toml`, so they cannot drift. Never edit the generated files: edit `cases.toml` and regenerate.

## Adding a case

Append a `[[resource.case]]` block to `cases.toml`. Absent `name` or `description` means "expected none". The element under test is flagged with `data-subject=""`; the generator replaces that marker with `id`, `data-case` and the `data-expected-*` attributes, and leaves the rest of the markup verbatim.

Keys: `id`, `title`, `name`, `description`, `note`, `divergence`, `skipped`, `markup`. Backticks in prose become `<code>`.

## epubcheck

`generate.py` runs `epubcheck` when it is on the `PATH` and diffs its output against `epubcheck-baseline.txt`.

The sample cannot be entirely epubcheck-clean: several cases exist precisely to pin down what we do with markup that is *deliberately* malformed — dangling `aria-labelledby`/`aria-describedby` IDREFs, `aria-hidden="TRUE"`, uppercase and multi-token `role` values. Dropping them would drop the behaviour the sample documents.

The baseline keeps the check meaningful anyway: any message that is not already accounted for fails the run. After adding a case that is knowingly invalid, run `python3 generate.py --update-epubcheck-baseline`.

## Unit tests

- `/Tests/SharedTests/Publication/Services/Content/Iterators/AccnameSampleTests.swift` runs each document through `HTMLResourceContentIterator` and matches every emitted element to its case through the `#case-<id>` CSS selector.
- `/Sources/Navigator/EPUB/Scripts/test/accname-sample.test.ts` loads the fixtures into jsdom and runs `computeAccessibilityProperties` over every `[data-case]` element.

Both skip cases flagged `skipped = true`, which describe rules that are not implemented yet (all of `table.xhtml`). Removing those flags is the acceptance test for a future implementation.
