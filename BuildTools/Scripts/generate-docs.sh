#!/bin/bash
# =============================================================================
#  Readium Swift Toolkit - Documentation Generator
# =============================================================================
#  This script automates the creation of a static DocC documentation site.
#  It handles:
#    1. Cross-compiling the Swift package for the iOS Simulator.
#    2. Generating symbol graphs (API metadata) for all modules.
#    3. filtering out 3rd-party dependencies from the docs.
#    4. Assembling the DocC catalog from the 'docs/' folder.
#    5. Converting everything into a static HTML website.
# =============================================================================

set -e # Exit immediately if any command exits with a non-zero status.

# -----------------------------------------------------------------------------
# 1. Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$PROJECT_ROOT"

echo "📂  Working directory set to: $(pwd)"

DOC_VERSION="${1:-latest}"
REPO_NAME="swift-toolkit"
# The final folder where the static HTML site will be generated.
OUTPUT_ROOT="docs-site"
# The site inside is nested in a folder matching the repo name.
# This emulates GitHub Pages URL structure (e.g., username.github.io/swift-toolkit/).
SITE_DIR="$OUTPUT_ROOT/$REPO_NAME/$DOC_VERSION"
# A temporary directory for intermediate build artifacts.
TEMP_DIR=".build-docs"
# The location of the "virtual" DocC catalog.
DOCC_CATALOG_DIR="$TEMP_DIR/Readium.docc"
# Where SwiftPM will dump the raw symbol graph JSON files.
SYMBOL_GRAPHS_DIR="$TEMP_DIR/symbol-graphs"

# -----------------------------------------------------------------------------
# 2. Argument Parsing
# -----------------------------------------------------------------------------
SERVE_SITE=false
for arg in "$@"; do
    if [ "$arg" == "--serve" ]; then
        SERVE_SITE=true
    fi
done

# -----------------------------------------------------------------------------
# 3. Cleanup
# -----------------------------------------------------------------------------
# Remove previous outputs to ensure a clean build.
# This prevents stale files or old symbols from appearing in the new site.
rm -rf "$SITE_DIR"
mkdir -p "$DOCC_CATALOG_DIR"
mkdir -p "$SYMBOL_GRAPHS_DIR"
mkdir -p "$SITE_DIR"

echo "⚙️  Configuring build environment..."

# -----------------------------------------------------------------------------
# 4. Environment Setup (Cross-Compilation)
# -----------------------------------------------------------------------------
# DocC requires a build to generate symbol graphs.
# Because this project imports 'UIKit', it CANNOT be built with macOS.
# It must cross-compile with the iOS Simulator.

# Find the path to the iOS Simulator SDK on the current machine.
SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)

# Determine the host architecture (arm64 for Apple Silicon, x86_64 for Intel)
# and construct a target triple for the compiler (e.g., arm64-apple-ios15.0-simulator).
HOST_ARCH=$(uname -m)
TARGET_TRIPLE="${HOST_ARCH}-apple-ios15.0-simulator"

echo "   • SDK: $SDK_PATH"
echo "   • Target: $TARGET_TRIPLE"

# -----------------------------------------------------------------------------
# 5. Build & Symbol Generation
# -----------------------------------------------------------------------------
echo "🔧  Patching Package.swift for macOS compatibility..."
# Define a cleanup function to restore the original file on exit/error
restore_package() {
    if [ -f Package.swift.orig ]; then
        mv Package.swift.orig Package.swift
    fi
}
trap restore_package EXIT

# Back up the original file
cp Package.swift Package.swift.orig

# Inject .macOS(.v11) into the platforms array
# This satisfies the dependency graph validation for ReadiumZIPFoundation
sed -i '' 's/\(\.iOS("[^"]*")\)]/\1, .macOS(.v11)]/' Package.swift

echo "🧹  Cleaning build artifacts..."
# Delete the .build folder to force SwiftPM to re-emit symbol graphs.
# If this isn't done, incremental builds might skip the documentation step.
rm -rf .build

echo "⚙️  Building symbol graphs..."
# Run 'swift build' with specific flags:
#   --sdk / --triple: Forces the build to target iOS Simulator (enabling UIKit).
#   -Xswiftc -emit-symbol-graph: Tells the Swift compiler to generate documentation data.
#   -Xswiftc -emit-symbol-graph-dir: Tells it where to save the .symbols.json files.
swift build \
    --sdk "$SDK_PATH" \
    --triple "$TARGET_TRIPLE" \
    -Xswiftc -emit-symbol-graph \
    -Xswiftc -emit-symbol-graph-dir -Xswiftc "$SYMBOL_GRAPHS_DIR"

# -----------------------------------------------------------------------------
# 6. Filter Dependencies
# -----------------------------------------------------------------------------
echo "🧹  Filtering dependencies..."
# SwiftPM generates documentation for EVERYTHING in the dependency graph.
# Only Readium modules go in the sidebar.
# Find all .symbols.json files that do NOT start with "Readium" and delete them.
find "$SYMBOL_GRAPHS_DIR" -type f -name "*.symbols.json" ! -name "Readium*" -delete

# -----------------------------------------------------------------------------
# 7. Prepare Documentation Catalog
# -----------------------------------------------------------------------------
echo "📄  Preparing documentation catalog..."

# We create a temporary DocC bundle structure
# and copy the contents of the 'docs' folder into it.
if [ -d "docs" ]; then
    cp -R docs/* "$DOCC_CATALOG_DIR/"
else
    echo "⚠️  Warning: 'docs' folder not found. Site may be empty."
fi

# Validation: Ensure the root landing page exists.
# Without this file, DocC will fail or produce an empty root.
if [ ! -f "$DOCC_CATALOG_DIR/Readium.md" ]; then
    echo "❌  Error: docs/Readium.md is missing."
    echo "    Please create this file with @TechnologyRoot metadata."
    exit 1
fi

echo "🚀  Generating site..."

# -----------------------------------------------------------------------------
# 8. DocC Conversion (Static Site Generation)
# -----------------------------------------------------------------------------
# Find the 'docc' tool inside Xcode.
DOCC_EXEC=$(xcrun --find docc)

# Run the conversion:
#   --additional-symbol-graph-dir: Where the filtered symbols are stored.
#   --transform-for-static-hosting: Generates a site compatible with GitHub Pages.
#   --hosting-base-path: Critical for GitHub Pages. Sets the root URL path (e.g. /swift-toolkit/).
$DOCC_EXEC convert "$DOCC_CATALOG_DIR" \
    --additional-symbol-graph-dir "$SYMBOL_GRAPHS_DIR" \
    --output-dir "$SITE_DIR" \
    --fallback-display-name "Readium" \
    --transform-for-static-hosting \
    --hosting-base-path "$REPO_NAME/$DOC_VERSION"

echo "✅  Documentation generated at: $SITE_DIR"

# -----------------------------------------------------------------------------
# 9. Add SPA Routing (Fixes Root & Deep Links)
# -----------------------------------------------------------------------------
echo "twisted_rightwards_arrows  Adding 404 redirect for SPA routing..."

# This script handles the redirect for both the root path AND deep links.
cat <<EOF > "$SITE_DIR/404.html"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Redirecting...</title>
    <script>
        // The path we expect for this specific version
        var versionPath = "/$REPO_NAME/$DOC_VERSION";
        var destination = versionPath + "/documentation/readium";
        
        // Redirect to the version's root documentation page
        window.location.href = destination;
    </script>
    <meta http-equiv="refresh" content="0; url=/$REPO_NAME/$DOC_VERSION/documentation/readium">
</head>
<body>
    <p>Redirecting to documentation...</p>
</body>
</html>
EOF

cp "$SITE_DIR/index.html" "$SITE_DIR/404.html"

# -----------------------------------------------------------------------------
# 10. Local Preview
# -----------------------------------------------------------------------------
if [ "$SERVE_SITE" = true ]; then
    URL="http://localhost:8080/$REPO_NAME/$DOC_VERSION/documentation/readium"
    echo "🌍  Serving at $URL"
    
    # Open the browser
    open "$URL" 2>/dev/null || true
    
    # Run a simple Python HTTP server to serve the static files.
    # Serve from OUTPUT_ROOT so the subdirectory /swift-toolkit/ exists.
    python3 -m http.server -d "$OUTPUT_ROOT" 8080
else
    echo "    Run 'BuildTools/Scripts/generate-docs.sh --serve' to preview."
fi
