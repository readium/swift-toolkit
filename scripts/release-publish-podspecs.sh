#!/usr/bin/env bash
# =============================================================================
# release-publish-podspecs.sh [--start INDEX]
# =============================================================================
# Push all podspecs to the Readium CocoaPods repo in dependency-safe order,
# with interactive retry on failure.
#
# --start INDEX - Resume the sequence from INDEX (0-based). Useful when a
# previous run was interrupted.
# =============================================================================

set -euo pipefail

. "$(cd "$(dirname "$0")" && pwd)/release-common.sh"

# Podspec order (dependency-safe)
PODSPECS=(
    "ReadiumInternal"
    "ReadiumShared"
    "ReadiumStreamer"
    "ReadiumNavigator"
    "ReadiumOPDS"
    "ReadiumLCP"
)

# Argument parsing
START_INDEX=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --start)
            START_INDEX="${2:?'--start requires an INDEX argument'}"
            shift 2
            ;;
        *)
            error "Unknown argument: $1. Usage: $(basename "$0") [--start INDEX]"
            ;;
    esac
done

MAX_INDEX=$(( ${#PODSPECS[@]} - 1 ))
if [[ "$START_INDEX" -lt 0 || "$START_INDEX" -gt "$MAX_INDEX" ]]; then
    error "--start INDEX must be between 0 and $MAX_INDEX"
fi

# Prerequisites
command -v pod &>/dev/null || error "'pod' (CocoaPods) not found on PATH"

# Repo setup
if ! pod repo list | sed $'s/\033\\[[0-9;]*m//g' | grep -q '^readium'; then
    info "Adding 'readium' CocoaPods repo"
    pod repo add readium git@github.com:readium/podspecs.git
fi

info "Updating CocoaPods repos"
pod repo update

# Push loop
cd "$REPO_ROOT/Support/CocoaPods"

for (( i = START_INDEX; i < ${#PODSPECS[@]}; i++ )); do
    NAME="${PODSPECS[$i]}"
    info "[$i/${MAX_INDEX}] Pushing ${NAME}.podspec"

    while true; do
        if pod repo push readium "${NAME}.podspec"; then
            info "  ✓ ${NAME} pushed successfully."
            break
        else
            echo ""
            echo "  Push failed for ${NAME} (index ${i})."
            read -r -p "  Retry? [Y/n] " REPLY
            REPLY="${REPLY:-Y}"
            if [[ "$REPLY" =~ ^[Nn]$ ]]; then
                echo ""
                echo "Stopped at index ${i}."
                echo "Resume with:  $(basename "$0") --start ${i}"
                exit 1
            fi
        fi
    done
done

info "All podspecs pushed successfully."
