---
name: update-changelog
description: Updates or adds entries to CHANGELOG.md based on the changes in the
  current branch. Use this skill whenever the user asks to update the changelog,
  add a changelog entry or document changes.
---

# Update CHANGELOG

## Overview

You are writing changelog entries for the **Readium Swift Toolkit**.
The audience is **app developers** who integrate this toolkit – not contributors.
Entries tell them what changed and, when necessary, how to adapt their code.

## CHANGELOG format

The file is at `CHANGELOG.md`. New entries go under `## [Unreleased]`.

Structure within `[Unreleased]`:

```
## [Unreleased]

### Added
#### Playground
#### Shared
#### Navigator

### Deprecated
...

### Changed
#### Playground
...

### Fixed
...
```

Omit the sub-section heading for cross-cutting changes.

## Entry style

- Start each bullet with a past-tense verb or a noun phrase: "Added", "Fixed", "The X now…"
- Be concise — one to three lines maximum per entry.
- Mention the **public API surface** (type name, method name, protocol name) in backticks.
- Do **not** explain implementation details; focus on what the developer observes or must do.
- Link to an existing guide when the change is non-trivial to adopt:
  - Migration steps: `[the migration guide](docs/Migration%20Guide.md)` (or a specific anchor)
  - New feature guide: `[the user guide](docs/Guides/...)` if a guide exists
- When the API is gated behind an experimental SPI, mention it.
- Prefix Fixed entries with the GitHub issue: `- [#NNN](URL) Fixed ...`.
- Contributions: append `(contributed by [@handle](PR URL))` when crediting external contributors.

## Process

1. **Read the diff** — run `git log --oneline <base>..HEAD` and `git diff <base>..HEAD` to understand what changed. Use `develop` as the base branch unless told otherwise.
2. **Read the existing `[Unreleased]` section** to avoid duplicating entries that are already there.
3. **Read `docs/Migration Guide.md`** to check whether the changes are already documented there; if so, link to the relevant section in the changelog entry.
4. **Draft entries** grouped by section and sub-section. When in doubt whether something is worth documenting:
   - Public API additions/changes/removals → always document
   - Bug fixes visible to the developer → document
   - Internal refactoring with no public API impact → skip
   - Test-only changes → skip
5. **Insert** the new entries into `CHANGELOG.md` under `## [Unreleased]`, creating sections/sub-sections as needed. Preserve the existing content.
6. **Review** the changelog entries to make sure the mentioned APIs are correct.
7. **Show the user** the diff of what you added and ask for confirmation before finalizing.

## Examples of good entries

```markdown
### Added

#### Playground

* New `Playground` iOS app – a minimal SwiftUI sample demonstrating how to use the Readium Swift Toolkit and to test its API.
    * `Recipes/` contains self-contained and explained code you can reuse in your own application.
    * `App/` folder contains the scaffolding (file management, navigation, error handling) needed to run the Playground.

#### Shared

* Added support for SVG covers in `ResourceCoverService`. SVG images can now be used as publication covers and are rendered to bitmaps (contributed by [@grighakobian](https://github.com/readium/swift-toolkit/pull/751)).
* `Publication` has a new experimental `coverData(accepting:)` API that returns the raw bytes and media type of the cover, useful for storing the original cover without re-encoding.

### Fixed

#### Navigator

* [#721](https://github.com/readium/swift-toolkit/issues/721) Fixed position of EPUB decorations when using the paragraph indent preference.
```
