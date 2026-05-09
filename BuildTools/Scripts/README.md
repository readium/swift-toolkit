# BuildTools/Scripts

Utility scripts for building, generating, and releasing the Readium Swift Toolkit.

## Release Scripts

These scripts automate the manual steps described in [MAINTAINING.md](../../MAINTAINING.md). Run them in the order listed below.

### `release-prepare.sh VERSION`

**Purpose:** Creates the release branch, bumps all version strings, closes the CHANGELOG and Migration Guide, commits, and opens a PR.

**When to run:** Steps 6a–6e of the release workflow.

**Usage:**
```sh
BuildTools/Scripts/release-prepare.sh 3.9.0
```

**Prerequisites:**
- `git`, `gh`, `make`, `python3` on PATH
- Currently on the `develop` branch, clean working tree, in sync with `origin/develop`
- Makefile has a `podspecs` target

**Files modified:** `Support/CocoaPods/Specs.swift`, `Support/CocoaPods/*.podspec`, `README.md`, `TestApp/Sources/Info.plist`, `CHANGELOG.md`, `docs/Migration Guide.md`

---

### `release-publish-podspecs.sh [--start INDEX]`

**Purpose:** Pushes all 8 podspecs to the Readium CocoaPods repo in dependency-safe order, with interactive retry on failure.

**When to run:** Step 6g of the release workflow (after the PR is merged and the tag is pushed).

**Usage:**
```sh
# Push all podspecs from the beginning:
BuildTools/Scripts/release-publish-podspecs.sh

# Resume after a failure at index 3:
BuildTools/Scripts/release-publish-podspecs.sh --start 3
```

**Prerequisites:** CocoaPods (`pod`) on PATH; SSH access to `git@github.com:readium/podspecs.git`.

**Podspec push order:**
```
0: ReadiumInternal
1: ReadiumShared
2: ReadiumStreamer
3: ReadiumNavigator
4: ReadiumOPDS
5: ReadiumLCP
6: ReadiumAdapterGCDWebServer
7: ReadiumAdapterLCPSQLite
```

---

### `release-tag.sh VERSION`

**Purpose:** Fast-forwards the local `develop` branch to `origin/develop`, verifies the last commit is the release PR merge, then creates an annotated tag and pushes it.

**When to run:** Step 6i of the release workflow (after squash-merging the release PR).

**Usage:**
```sh
BuildTools/Scripts/release-tag.sh 3.9.0
```

**Prerequisites:** On `develop`; the release PR must be squash-merged with commit message `VERSION (#N)`.

---

### `release-github.sh VERSION`

**Purpose:** Creates a draft GitHub release pre-filled with formatted release notes (warning callout, documentation links, extracted changelog content).

**When to run:** Step 8a of the release workflow (after pushing the tag).

**Usage:**
```sh
BuildTools/Scripts/release-github.sh 3.9.0
```

**Prerequisites:** `gh` authenticated (`gh auth status`); `python3` on PATH; the VERSION tag must exist locally.

---

## Helper Scripts (called by release scripts)

| Script | Called by | Purpose |
|--------|-----------|---------|
| `release-update-readme.py VERSION OLD_VERSION README_PATH` | `release-prepare.sh` | Bumps CocoaPods pod lines and the Minimum Requirements table in README.md |
| `release-close-changelog.py OLD_VERSION VERSION CHANGELOG_PATH` | `release-prepare.sh` | Comments out `## [Unreleased]`, inserts `## [VERSION] - DATE`, appends compare link |
| `release-close-migration-guide.py VERSION GUIDE_PATH` | `release-prepare.sh` | Comments out `## Unreleased`, inserts `## VERSION` (only when section is present) |
| `release-extract-changelog.py VERSION CHANGELOG_PATH` | `release-github.sh` | Extracts and prints the body of a `## [VERSION]` section |

---

## Other Scripts

### `convert-thorium-localizations.js`

Converts Thorium localization JSON files into the format used by the Swift toolkit. Invoked automatically by `make update-locales` — do not run directly.

### `generate-a11y-extensions.js`

Generates Swift accessibility extension files from a structured spec. Run this whenever the accessibility spec changes.

### `generate-docs.sh [--serve]`

Builds a static DocC documentation site for deployment to readium.org. Pass `--serve` to preview locally at `http://localhost:8080/swift-toolkit/`.

```sh
BuildTools/Scripts/generate-docs.sh
BuildTools/Scripts/generate-docs.sh --serve
```
