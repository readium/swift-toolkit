#!/usr/bin/env bash

# helpers for the `release-*.sh` scripts.

# Absolute path to this scripts/ directory and the repo root.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Print an informational message.
info()  { echo "▶ $*"; }
# Print an error message to stderr and exit with code 1.
error() { echo "✗ $*" >&2; exit 1; }

# Validate that $1 is a semver string of the form a.b or a.b.c.
check_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || \
        error "'$1' is not valid semver (expected a.b or a.b.c)"
}

# Print a "Dry-run: skipped" message for an operation that was not executed.
dry_skip() { echo "Dry-run: skipped \"$*\""; }

# Globals set by parse_flags; read by each script after calling it.
DRY_RUN=0 # 1 when --dry-run is passed
SKIP_GIT_CHECKS=0 # 1 when --skip-git-checks is passed

# Print positional arguments from "$@", one per line, stripping any --flags.
# Usage: VAR="$(positional_args "$@")"
positional_args() {
    for arg in "$@"; do [[ "$arg" == --* ]] || echo "$arg"; done
}

# Parse [--dry-run] [--skip-git-checks] from "$@".
# Sets DRY_RUN and SKIP_GIT_CHECKS.
parse_flags() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) DRY_RUN=1; shift ;;
            --skip-git-checks) SKIP_GIT_CHECKS=1; shift ;;
            -*) error "Unknown argument: $1" ;;
            *) break ;;
        esac
    done
}

