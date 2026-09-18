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
if [[ "$LAST_MSG" =~ ^([0-9]+\.[0-9]+(\.[0-9]+)?(-(alpha|beta|rc)\.[0-9]+)?)( \(#[0-9]+\))?$ ]]; then
    VERSION="${BASH_REMATCH[1]}"
else
    error "Cannot extract version from last commit message: \"$LAST_MSG\"
  Expected format: \"a.b.c\" or \"a.b.c (#N)\"
Squash-merge the release PR before tagging."
fi
check_semver "$VERSION"

# A leftover local tag makes `git tag -a` fail, e.g. when a previous run was
# interrupted after the tag was created but before it was pushed.
! git -C "$REPO_ROOT" show-ref --verify --quiet "refs/tags/$VERSION" || \
    error "A local tag '$VERSION' already exists.
  If a previous run failed before pushing it, delete it and run this script again:
    git tag -d \"$VERSION\""

# Tag and push. The tag is pushed with a fully qualified refspec, so the release
# branch may still exist under the same name at this point.
if [[ $DRY_RUN -eq 1 ]]; then
    dry_skip "git tag -a \"$VERSION\" -m \"$VERSION\""
    dry_skip "git push origin \"refs/tags/$VERSION\""
else
    git -C "$REPO_ROOT" tag -a "$VERSION" -m "$VERSION"
    git -C "$REPO_ROOT" push origin "refs/tags/$VERSION"
fi

info "Tagged and pushed $VERSION."

# The release branch is named like the tag, so it is deleted to avoid ambiguous
# refs later on. It is usually already gone, as GitHub deletes it on
# squash-merge. This is only hygiene: a failure here must not mask the
# successful push above.
if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$VERSION"; then
    if [[ $DRY_RUN -eq 1 ]]; then
        dry_skip "git branch -D \"$VERSION\""
    else
        info "Deleting local release branch '$VERSION'"
        git -C "$REPO_ROOT" branch -D "$VERSION" || \
            info "Could not delete the local branch '$VERSION', delete it manually."
    fi
fi
