# Pragmatic subset of the W3C accessible name computation

The `accessibleName` and `accessibleDescription` of `ContentElement`s are
computed by a deliberately partial implementation of [accname-1.2] and
[HTML-AAM], duplicated in Swift (`HTMLAccessibilityProperties.swift`, over
SwiftSoup) and TypeScript (`accessibility-properties.ts`, over the live DOM).
We implement the source precedence, element-level
`aria-hidden`/presentational-role suppression
and HTML-AAM's img-specific rules (e.g. empty `alt` is decorative and blocks
the `title` fallback). We do NOT implement recursive traversal of referenced
targets (approximated one level: the target's `aria-label`, else its text
content), hidden-node exclusion beyond the element itself, CSS generated
content and a few other exceptions.

## Why

A conformant implementation is complex: the skipped branches require CSS and
layout knowledge that SwiftSoup does not have, so full fidelity is unreachable
on the Swift side regardless. Keeping both implementations small and comparable
protects correctness. A single case manifest
(`Tests/Samples/accessibility-properties/cases.toml`) is the executable
specification, it generates the fixtures both the Swift Testing and jest suites
run against.

## Consequences

Divergences from the spec are declared in the helpers' doc comments and must
stay in sync with the code. Markup relying on the skipped branches (chained
`aria-labelledby`, hidden-node filtering inside referenced targets, roles whose
naming is prohibited beyond `presentation`/`none`) computes a slightly
different name than a browser would.

Every implemented rule and declared divergence is written out as a section of
the accessibility properties sample, stating its expected name and description
in prose next to the markup under test. See
`Tests/Samples/accessibility-properties/README.md`;
`Tests/Samples/accessibility-properties/accessibility-properties.epub` can be
opened in a reader to check the behaviour by hand.

[accname-1.2]: https://www.w3.org/TR/accname-1.2/
[HTML-AAM]: https://www.w3.org/TR/html-aam-1.0/
