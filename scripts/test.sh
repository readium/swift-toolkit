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

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DESTINATION="platform=iOS Simulator,name=iPad (A16)"
FILTER="${1:-}"

CONFIGURATION="Test Scheme Action"
[ "${TSAN:-0}" = "1" ] && CONFIGURATION="Thread Sanitizer"

ARGS=(
    -project "$REPO_ROOT/TestApp/TestApp.xcodeproj"
    -scheme TestApp
    -testPlan TestApp
    -only-test-configuration "$CONFIGURATION"
    -destination "$DESTINATION"
)
[ -n "$FILTER" ] && ARGS+=(-only-testing:"$FILTER")

xcodebuild test "${ARGS[@]}" 2> /dev/null | xcbeautify --quieter --disable-logging | grep -Ev "^Executed |Test Suite 'All tests'|Test run started\.|Test session results:"; true
