#!/usr/bin/env bash
# =============================================================================
# test.sh [FILTER]
# =============================================================================
# Run the test suite.
#
# FILTER - Optional target to run (e.g. ReadiumSharedTests)
#
# Set TSAN=1 to run the "Thread Sanitizer" test plan configuration instead of
# the default one.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEVICE_NAME="iPad (A16)"
FILTER="${1:-}"

CONFIGURATION="Test Scheme Action"
[ "${TSAN:-0}" = "1" ] && CONFIGURATION="Thread Sanitizer"

PROJECT="$REPO_ROOT/Playground/Playground.xcodeproj"
if [ ! -d "$PROJECT" ]; then
    echo "Playground project not found. Run 'make playground' first, or" >&2
    echo "'make playground lcp=<url>' to also run the LCP tests." >&2
    exit 1
fi

# Pin the simulator to the runtime matching the selected Xcode, otherwise
# looking it up by name alone can pick a newer runtime. Tests depending on
# system frameworks such as PDFKit fail on a mismatched runtime.
OS_VERSION="$(xcrun --sdk iphonesimulator --show-sdk-version)"
RUNTIME_ID="com.apple.CoreSimulator.SimRuntime.iOS-${OS_VERSION//./-}"

UDID="$(
    xcrun simctl list devices --json | python3 -c '
import json, sys

runtime, name = sys.argv[1], sys.argv[2]
for device in json.load(sys.stdin)["devices"].get(runtime, []):
    if device["name"] == name and device.get("isAvailable"):
        print(device["udid"])
        break
' "$RUNTIME_ID" "$DEVICE_NAME"
)"

if [ -z "$UDID" ]; then
    echo "error: no available '$DEVICE_NAME' simulator for iOS $OS_VERSION" >&2
    exit 1
fi

# Boot the simulator up-front and leave it running, so that repeated runs skip
# the cold boot.
xcrun simctl bootstatus "$UDID" -b > /dev/null

ARGS=(
    -project "$PROJECT"
    -scheme Playground
    -only-test-configuration "$CONFIGURATION"
    -destination "platform=iOS Simulator,id=$UDID"
    # Skip the package graph resolution, which hits the network on every run.
    # Fails loudly when Package.resolved is out of date.
    -disableAutomaticPackageResolution
    -onlyUsePackageVersionsFromResolvedFile
    -skipPackagePluginValidation
    -skipMacroValidation
)
[ -n "$FILTER" ] && ARGS+=(-only-testing:"$FILTER")

STDERR_LOG="$(mktemp -t readium-test)"
trap 'rm -f "$STDERR_LOG"' EXIT

xcodebuild test "${ARGS[@]}" \
    2> "$STDERR_LOG" \
    | xcbeautify --quieter --disable-logging \
    | { grep -Ev "^Executed |Test Suite 'All tests'|Test run started\.|Test session results:" || true; }

STATUS=${PIPESTATUS[0]}

if [ "$STATUS" -ne 0 ]; then
    cat "$STDERR_LOG" >&2
fi

exit "$STATUS"
