# Pragmatic subset of the W3C accessible name computation

The `accessibilityName` and `accessibilityDescription` of `ContentElement`s are
computed by a deliberately partial implementation of [accname-1.2] and
[HTML-AAM], duplicated in Swift (`HTMLAccessibilityProperties.swift`, over
SwiftSoup) and TypeScript (`accname.ts`, over the live DOM). We implement the
source precedence (aria-labelledby → aria-label → host-language sources →
title), element-level `aria-hidden`/presentational-role suppression, the
description stop-on-first-markup rule, and HTML-AAM's img-specific rules
(empty `alt` is decorative and blocks the `title` fallback; figcaption names
an image that has no other name source and no sibling content). We do NOT
implement recursive traversal of referenced targets (approximated one level:
the target's `aria-label`, else its text content), hidden-node exclusion
beyond the element itself, CSS generated content, name-from-content, or
form-control value substitution.

## Why

A conformant implementation is a browser-engine-sized effort: the skipped
branches require CSS and layout knowledge that SwiftSoup does not have, so
full fidelity is unreachable on the Swift side regardless. Keeping both
implementations small and line-for-line comparable is what actually protects
correctness here: a single case manifest
(`scripts/accname-sample/cases.toml`) is the executable specification, it
generates the fixtures both the Swift Testing and jest suites run against,
and review keeps the code in lockstep. The skipped branches exist for
dynamic web applications; packaged
book content essentially never exercises them.

## Considered options

- **Full recursive algorithm**: rejected — unimplementable over SwiftSoup
  (no CSS), and the DOM side deliberately mirrors the Swift subset rather
  than exceeding it, so the two never drift apart.
- **Attributes only (no ID resolution)**: rejected — `aria-describedby` is
  the standard mechanism for extended image descriptions in accessible EPUB,
  and dropping it would leave `accessibilityDescription` empty in practice.

## Consequences

Divergences from the spec are declared in the helpers' doc comments and must
stay in sync with the code. Markup relying on the skipped branches (chained
`aria-labelledby`, hidden-node filtering inside referenced targets, roles
whose naming is prohibited beyond `presentation`/`none`) computes a slightly
different name than a browser would.

Every implemented rule and declared divergence is written out as a section of
the `accname` sample, stating its expected name and description in prose next
to the markup under test. See `scripts/accname-sample/README.md`;
`scripts/accname-sample/accname.epub` can be opened in a reader to check the
behaviour by hand. The sample also sketches the host-language sources we have
*not* implemented (`<table>` naming), flagged so that neither suite asserts
them.

[accname-1.2]: https://www.w3.org/TR/accname-1.2/
[HTML-AAM]: https://www.w3.org/TR/html-aam-1.0/
