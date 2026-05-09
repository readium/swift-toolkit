#!/usr/bin/env bash

# helpers for the `release-*.sh` scripts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

info()  { echo "▶ $*"; }
error() { echo "✗ $*" >&2; exit 1; }

check_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || \
        error "'$1' is not valid semver (expected a.b or a.b.c)"
}
