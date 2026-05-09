#!/usr/bin/env bash
# =============================================================================
# release-github.sh [--dry-run] [--skip-git-checks] VERSION
# =============================================================================
# Create a draft GitHub release pre-filled with formatted release notes drawn
# from CHANGELOG.md.
#
# VERSION - The version to release (e.g. 3.9.0) — tag must exist locally
# --dry-run - Skip the actual GitHub release creation.
# --skip-git-checks - Skip the local tag existence check
# =============================================================================

set -euo pipefail

. "$(cd "$(dirname "$0")" && pwd)/release-common.sh"

parse_flags "$@"

# Prerequisites
command -v gh &>/dev/null || error "'gh' CLI not found — install from https://cli.github.com"
command -v python3 &>/dev/null || error "'python3' not found"

if [[ $SKIP_GIT_CHECKS -eq 0 ]]; then
    git -C "$REPO_ROOT" rev-parse "$VERSION" &>/dev/null || \
        error "Tag '$VERSION' not found locally."
fi

# Changelog content
info "Extracting changelog section for $VERSION"
CHANGELOG_CONTENT="$(python3 "$SCRIPT_DIR/release-md-tools.py" extract-changelog "$VERSION" "$REPO_ROOT/CHANGELOG.md")"

# Migration guide anchor
MIGRATION_GUIDE="$REPO_ROOT/docs/Migration Guide.md"
MG_ANCHOR=""

while IFS= read -r line; do
    # Skip commented headings.
    [[ "$line" =~ ^[[:space:]]*"<!--" ]] && continue
    # Match the first uncommented level-2 heading.
    if [[ "$line" =~ ^##[[:space:]]+(.+)$ ]]; then
        HEADING_TEXT="${BASH_REMATCH[1]}"
        # Strip spaces and dots to build the anchor (e.g. "3.9.0" → "390").
        MG_ANCHOR="$(echo "$HEADING_TEXT" | tr -d ' .')"
        break
    fi
done < "$MIGRATION_GUIDE"

# Build release body
TMPFILE="$(mktemp /tmp/release-notes-XXXXXX)"

cat > "$TMPFILE" <<BODY
> [!WARNING]
> Minor releases (\`a.B.c\`) of the Readium toolkit may now include minor breaking changes, such as dependency upgrades or small API modifications. Major version numbers are reserved for significant architectural changes.

## Documentation

* [**Versioned Documentation**](https://readium.org/swift-toolkit/${VERSION}/documentation/readium/)
* [**Migration Guide**](docs/Migration%20Guide.md#${MG_ANCHOR})

## Changelog

${CHANGELOG_CONTENT}

BODY

# Create draft release
info "Creating draft GitHub release for $VERSION"
if [[ $DRY_RUN -eq 1 ]]; then
    dry_skip "gh release create $VERSION --title $VERSION --notes-file $TMPFILE --draft"
    echo ""
    echo "=== Release: $VERSION ==="
    echo ""
    cat "$TMPFILE"
    echo ""
else
    RELEASE_URL="$(gh release create "$VERSION" \
        --title "$VERSION" \
        --notes-file "$TMPFILE" \
        --draft)"
    info "Draft release created: $RELEASE_URL"
    open "$RELEASE_URL"
fi
