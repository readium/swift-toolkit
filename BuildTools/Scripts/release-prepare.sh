#!/usr/bin/env bash
# =============================================================================
# release-prepare.sh VERSION
# =============================================================================
# Create the release branch, bump all version strings, close the CHANGELOG and
# Migration Guide, commit, and open a PR.
#
# VERSION - The new version to release (e.g. 3.9.0)
# =============================================================================

set -euo pipefail

. "$(cd "$(dirname "$0")" && pwd)/release-common.sh"

VERSION="${1:-}"
[[ -n "$VERSION" ]] || error "Usage: $(basename "$0") VERSION"

check_semver "$VERSION"

# Prerequisite checks
command -v gh &>/dev/null || error "'gh' CLI not found — install from https://cli.github.com"
command -v python3 &>/dev/null || error "'python3' not found"
command -v make &>/dev/null || error "'make' not found"

CURRENT_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
[[ "$CURRENT_BRANCH" == "develop" ]] || \
    error "Must be on the 'develop' branch (currently on '$CURRENT_BRANCH')"

git -C "$REPO_ROOT" fetch origin

LOCAL_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
REMOTE_SHA="$(git -C "$REPO_ROOT" rev-parse origin/develop)"
# [[ "$LOCAL_SHA" == "$REMOTE_SHA" ]] || \
#     error "Local 'develop' is not in sync with 'origin/develop'. Pull or push first."

[[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ]] || \
    error "Working tree is not clean. Commit or stash changes first."

grep -q '^podspecs:' "$REPO_ROOT/Makefile" || \
    error "'podspecs' target not found in Makefile"

# Old version
OLD_VERSION="$(git -C "$REPO_ROOT" describe --tags --abbrev=0)"
check_semver "$OLD_VERSION"
info "Preparing release $OLD_VERSION → $VERSION"

# Branch
info "Creating branch '$VERSION'"
git -C "$REPO_ROOT" checkout -b "$VERSION"

# Support/CocoaPods/Specs.swift
SPECS_FILE="$REPO_ROOT/Support/CocoaPods/Specs.swift"
info "Bumping version in Specs.swift"
sed -i '' "s/let version = \"$OLD_VERSION\"/let version = \"$VERSION\"/" "$SPECS_FILE"

# Podspecs
info "Regenerating podspecs (make podspecs)"
make -C "$REPO_ROOT" podspecs > /dev/null

# README.md
info "Bumping version in README.md"
python3 "$SCRIPT_DIR/release-md-tools.py" update-readme "$VERSION" "$OLD_VERSION" "$REPO_ROOT/README.md"

# TestApp/Sources/Info.plist
PLIST_FILE="$REPO_ROOT/TestApp/Sources/Info.plist"
info "Bumping version in TestApp/Sources/Info.plist"
sed -i '' "s|<string>${OLD_VERSION}</string>|<string>${VERSION}</string>|g" "$PLIST_FILE"

# CHANGELOG.md
info "Closing CHANGELOG.md for $VERSION"
python3 "$SCRIPT_DIR/release-md-tools.py" close-changelog "$OLD_VERSION" "$VERSION" "$REPO_ROOT/CHANGELOG.md"

# Docs/Migration Guide.md
MIGRATION_GUIDE="$REPO_ROOT/docs/Migration Guide.md"
info "Closing Migration Guide (if needed)"
python3 "$SCRIPT_DIR/release-md-tools.py" close-migration-guide "$VERSION" "$MIGRATION_GUIDE"

# Commit
info "Staging and committing"
git -C "$REPO_ROOT" add \
    "$SPECS_FILE" \
    "$REPO_ROOT/Support/CocoaPods"/*.podspec \
    "$REPO_ROOT/README.md" \
    "$PLIST_FILE" \
    "$REPO_ROOT/CHANGELOG.md" \
    "$MIGRATION_GUIDE"
git -C "$REPO_ROOT" commit -m "$VERSION"

# Push + PR
info "Pushing branch '$VERSION'"
# git -C "$REPO_ROOT" push -u origin "$VERSION"

info "Creating PR"
# PR_URL="$(gh pr create --base develop --title "$VERSION" --body "" | tail -1)"
# open "$PR_URL"
