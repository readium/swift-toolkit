#!/usr/bin/env bash
# =============================================================================
# release-prepare.sh [--dry-run] [--skip-git-checks] VERSION
# =============================================================================
# Create the release branch, bump all version strings, close the CHANGELOG and
# Migration Guide, commit, and open a PR.
#
# VERSION - The new version to release (e.g. 3.9.0)
# --dry-run - Skip `git push` and `gh pr create`
# --skip-git-checks - Skip branch and clean working tree checks
# =============================================================================

set -euo pipefail

. "$(cd "$(dirname "$0")" && pwd)/release-common.sh"

parse_flags "$@"

VERSION="$(positional_args "$@")"
[[ -n "$VERSION" ]] || error "Usage: $(basename "$0") [--dry-run] [--skip-git-checks] VERSION"
check_semver "$VERSION"

# Prerequisite checks
command -v gh &>/dev/null || error "'gh' CLI not found — install from https://cli.github.com"
command -v node &>/dev/null || error "'node' not found"
command -v python3 &>/dev/null || error "'python3' not found"
command -v make &>/dev/null || error "'make' not found"

if [[ $SKIP_GIT_CHECKS -eq 0 ]]; then
    CURRENT_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
    [[ "$CURRENT_BRANCH" == "develop" ]] || \
        error "Must be on the 'develop' branch (currently on '$CURRENT_BRANCH')"

    git -C "$REPO_ROOT" fetch origin

    LOCAL_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
    REMOTE_SHA="$(git -C "$REPO_ROOT" rev-parse origin/develop)"
    [[ "$LOCAL_SHA" == "$REMOTE_SHA" ]] || \
        error "Local 'develop' is not in sync with 'origin/develop'. Pull or push first."
fi

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
info "Bumping version in Specs.swift"
sed -i '' "s/let version = \"$OLD_VERSION\"/let version = \"$VERSION\"/" "$REPO_ROOT/Support/CocoaPods/Specs.swift"

# Podspecs
info "Regenerating podspecs (make podspecs)"
make -C "$REPO_ROOT" podspecs > /dev/null

# README.md
info "Bumping version in README.md"
python3 "$SCRIPT_DIR/release-md-tools.py" update-readme "$VERSION" "$OLD_VERSION" "$REPO_ROOT/README.md"

# TestApp/Sources/Info.plist
info "Bumping version in TestApp/Sources/Info.plist"
sed -i '' "s|<string>${OLD_VERSION}</string>|<string>${VERSION}</string>|g" "$REPO_ROOT/TestApp/Sources/Info.plist"

# CHANGELOG.md
info "Closing CHANGELOG.md for $VERSION"
python3 "$SCRIPT_DIR/release-md-tools.py" close-changelog "$OLD_VERSION" "$VERSION" "$REPO_ROOT/CHANGELOG.md"

# Docs/Migration Guide.md
info "Closing Migration Guide (if needed)"
python3 "$SCRIPT_DIR/release-md-tools.py" close-migration-guide "$VERSION" "$REPO_ROOT/docs/Migration Guide.md"

# Locales
info "Updating localized strings (make update-locales)"
make -C "$REPO_ROOT" update-locales > /dev/null

# Commit
info "Staging and committing"
if [[ $DRY_RUN -eq 1 ]]; then
    dry_skip "git add -u"
    dry_skip "git commit -m \"$VERSION\""
else
    git -C "$REPO_ROOT" add -u
    git -C "$REPO_ROOT" commit -m "$VERSION"
fi

# Push + PR
info "Pushing branch '$VERSION'"
if [[ $DRY_RUN -eq 1 ]]; then
    dry_skip "git push -u origin $VERSION"
    dry_skip "gh pr create --base develop --title \"$VERSION\" --body \"\""
else
    git -C "$REPO_ROOT" push -u origin "$VERSION"
    PR_URL="$(gh pr create --base develop --title "$VERSION" --body "" | tail -1)"
    open "$PR_URL"
fi
