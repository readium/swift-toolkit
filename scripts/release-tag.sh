#!/usr/bin/env bash
# =============================================================================
# release-tag.sh [--skip-git-checks] [--dry-run]
# =============================================================================
# Tag the new version from `develop` and push the tag.
#
# The version is extracted automatically from the last commit message on
# develop (expected format: `VERSION (#N)` or `VERSION`).
#
# --skip-git-checks - Skip branch check
# --dry-run - Skip the actual creation of the tag
# =============================================================================

set -euo pipefail

. "$(cd "$(dirname "$0")" && pwd)/release-common.sh"

parse_flags "$@"

if [[ $SKIP_GIT_CHECKS -eq 0 ]]; then
    # Branch check
    CURRENT_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
    [[ "$CURRENT_BRANCH" == "develop" ]] || \
        error "Must be on the 'develop' branch (currently on '$CURRENT_BRANCH')"

    # Fast-forward to latest origin/develop
    info "Fetching and fast-forwarding develop"
    git -C "$REPO_ROOT" fetch origin
    git -C "$REPO_ROOT" merge --ff-only origin/develop
fi

# Extract VERSION from the last commit message (format: "a.b.c" or "a.b.c (#N)")
LAST_MSG="$(git -C "$REPO_ROOT" log -1 --format="%s")"
if [[ "$LAST_MSG" =~ ^([0-9]+\.[0-9]+(\.[0-9]+)?)( \(#[0-9]+\))?$ ]]; then
    VERSION="${BASH_REMATCH[1]}"
else
    error "Cannot extract version from last commit message: \"$LAST_MSG\"
  Expected format: \"a.b.c\" or \"a.b.c (#N)\"
Squash-merge the release PR before tagging."
fi
check_semver "$VERSION"

# Tag and push
if [[ $DRY_RUN -eq 1 ]]; then
    dry_skip "git tag -a \"$VERSION\" -m \"$VERSION\""
    dry_skip "git push origin \"$VERSION\""
else
    git -C "$REPO_ROOT" tag -a "$VERSION" -m "$VERSION"
    git -C "$REPO_ROOT" push origin "$VERSION"
fi

info "Tagged and pushed $VERSION."
