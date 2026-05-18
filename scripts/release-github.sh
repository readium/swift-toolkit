#!/usr/bin/env bash
# =============================================================================
# release-github.sh [--dry-run]
# =============================================================================
# Create a draft GitHub release pre-filled with formatted release notes drawn
# from CHANGELOG.md.
#
# The version is determined automatically from the tag pointing to the last
# commit (HEAD). Run release-tag.sh first to create that tag.
# --dry-run - Skip the actual GitHub release creation.
# =============================================================================

set -euo pipefail

. "$(cd "$(dirname "$0")" && pwd)/release-common.sh"

parse_flags "$@"

# Prerequisites
command -v gh &>/dev/null || error "'gh' CLI not found — install from https://cli.github.com"
command -v python3 &>/dev/null || error "'python3' not found"

# Derive VERSION from the tag pointing to HEAD
VERSION="$(git -C "$REPO_ROOT" describe --tags --exact-match HEAD 2>/dev/null)" || \
    error "No tag found on HEAD."
check_semver "$VERSION"

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

* [**Versioned Documentation**](https://readium.org/swift-toolkit/${VERSION}/documentation/readium/) – Complete API reference on readium.org.
* [**Migration Guide**](docs/Migration%20Guide.md#${MG_ANCHOR}) – Instructions for upgrading from previous versions.

## Changelog

${CHANGELOG_CONTENT}

BODY

# Create draft release
info "Creating draft GitHub release for $VERSION"
if [[ $DRY_RUN -eq 1 ]]; then
    dry_skip "gh release create $VERSION --title $VERSION --notes-file $TMPFILE --generate-notes --draft"
    echo ""
    echo "=== Release: $VERSION ==="
    echo ""
    cat "$TMPFILE"
    echo ""
else
    RELEASE_URL="$(gh release create "$VERSION" --title "$VERSION" --notes-file "$TMPFILE" --generate-notes --draft)"
    info "Draft release created: $RELEASE_URL"
    open "$RELEASE_URL"
fi
