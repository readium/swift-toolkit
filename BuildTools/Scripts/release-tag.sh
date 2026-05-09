#!/usr/bin/env bash
# =============================================================================
# release-tag.sh VERSION
# =============================================================================
# Tag the new version from `develop` and push the tag.
#
# VERSION - The version to tag (e.g. 3.9.0) — must match the last commit
# message on develop (format: `VERSION (#N)`)
# =============================================================================

set -euo pipefail

. "$(cd "$(dirname "$0")" && pwd)/release-common.sh"

# Argument
VERSION="${1:-}"
[[ -n "$VERSION" ]] || error "Usage: $(basename "$0") VERSION"
check_semver "$VERSION"

# Branch check
CURRENT_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
[[ "$CURRENT_BRANCH" == "develop" ]] || \
    error "Must be on the 'develop' branch (currently on '$CURRENT_BRANCH')"

# Fast-forward to latest origin/develop
info "Fetching and fast-forwarding develop"
git -C "$REPO_ROOT" fetch origin
git -C "$REPO_ROOT" merge --ff-only origin/develop

# Verify last commit is the release pr merge
LAST_MSG="$(git -C "$REPO_ROOT" log -1 --format="%s")"
EXPECTED_PATTERN="^${VERSION//./\\.} \(#[0-9]+\)$"
[[ "$LAST_MSG" =~ $EXPECTED_PATTERN ]] || \
    error "Last commit on develop is not the release PR merge.
  Expected: \"$VERSION (#N)\"
  Got:      \"$LAST_MSG\"
Squash-merge the release PR before tagging."

# Tag and push
info "Tagging $VERSION"
git -C "$REPO_ROOT" tag -a "$VERSION" -m "$VERSION"

info "Pushing tag"
git -C "$REPO_ROOT" push --tags

info "Tagged and pushed $VERSION."
