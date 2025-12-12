# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Readium Swift Toolkit is a modular toolkit for building iOS/iPadOS reading applications that support ebooks (EPUB), PDFs, audiobooks, comics, and OPDS catalogs. It's divided into independent packages that can be used separately or together.

**Minimum Requirements:** iOS 13.4, Swift 6.0, Xcode 16.2 (develop branch)

## Core Packages

### ReadiumShared
Contains shared models and utilities used across all packages:
- `Publication`: Central model representing any publication (ebook, audiobook, comic). Based on Readium Web Publication Manifest.
- `Manifest`: Publication metadata, reading order, resources, and table of contents
- `Link`: Pointer to a resource with metadata (URL, media type, title)
- `Locator`: Precise location in a publication (for bookmarks, highlights, navigation)
- `Asset`: Access to file content (either `ContainerAsset` for archives or `ResourceAsset` for single files)
- `Resource`: Read access to individual resources
- `Container`: Read access to collections of resources

### ReadiumStreamer
Parses publication files into `Publication` objects:
- `AssetRetriever`: Retrieves assets from URLs
- `PublicationOpener`: Opens publications from assets, handles DRM
- `PublicationParser`: Parses different publication formats (EPUB, PDF, audiobooks, etc.)

### ReadiumNavigator
Renders publication content with interactive UI:
- `Navigator`: Protocol for all navigators with navigation methods (`go(to:)`, `goForward()`, `goBackward()`)
- `EPUBNavigatorViewController`: EPUB renderer (reflowable and fixed-layout)
- `PDFNavigatorViewController`: PDF renderer
- `AudioNavigator`: Audiobook player
- Preferences system for user settings (font size, colors, etc.)
- Decoration API for highlights and annotations

### ReadiumOPDS
Parses OPDS catalog feeds (both OPDS 1.x and 2.0).

### ReadiumLCP
Handles Readium LCP DRM-protected publications. Requires proprietary `R2LCPClient.framework` from EDRLab.

### Adapters
- `ReadiumAdapterGCDWebServer`: HTTP server using GCDWebServer
- `ReadiumAdapterLCPSQLite`: SQLite-based repositories for LCP licenses and passphrases

## Architecture

### Publication Flow
1. **Asset Retrieval**: `AssetRetriever` → `Asset` (from URL/file)
2. **DRM Handling**: `ContentProtection` checks and unlocks protected assets
3. **Parsing**: `PublicationParser` → `Publication.Builder` → `Publication`
4. **Services**: `PublicationService` instances attached to publications provide features like search, content extraction, positions
5. **Rendering**: `Navigator` displays publication using `WKWebView` (EPUB), `PDFKit` (PDF), or `AVPlayer` (audio)

### Key Patterns
- **Service Architecture**: Publications use a service pattern. Services like `SearchService`, `ContentService`, `PositionsService` are lazily instantiated and accessed via `publication.findService()`
- **Builder Pattern**: Publications are constructed via `Publication.Builder` which allows modification before finalization
- **Resource/Container Abstraction**: All content access goes through `Resource` and `Container` protocols, enabling uniform handling of local files, HTTP resources, and encrypted content

## Common Development Commands

### Building and Testing
```bash
# Run all unit tests
make test  # Uses xcodebuild with 'Readium-Package' scheme

# Build (run from repo root, not TestApp)
xcodebuild build-for-testing -scheme "Readium-Package" -destination "platform=iOS Simulator,name=iPhone SE (3rd generation)"

# Test without building
xcodebuild test-without-building -scheme "Readium-Package" -destination "platform=iOS Simulator,name=iPhone SE (3rd generation)"
```

### Code Quality
```bash
# Format all Swift code (REQUIRED before submitting PRs)
make format

# Check formatting without modifying files
make lint-format
```

### EPUB Navigator JavaScript
When modifying JavaScript in `Sources/Navigator/EPUB/Scripts/`:
```bash
# Install corepack first: https://pnpm.io/installation#using-corepack
make scripts  # Bundles and embeds JS into the app
```

The EPUB navigator injects JavaScript into publications:
- `index-reflowable.js`: Bundle for reflowable EPUBs
- `index-fixed.js`: Bundle for fixed-layout EPUBs
- Fixed-layout EPUBs use HTML wrappers (`fxl-spread-one.html`, `fxl-spread-two.html`) with corresponding `index-fixed-wrapper-*.js` bundles

### TestApp
The TestApp demonstrates integration patterns for all dependency managers (SPM, Carthage, CocoaPods). Generate the Xcode project using:
```bash
cd TestApp
make spm      # Swift Package Manager (recommended)
make dev      # Local development with SPM
make carthage # Carthage
make cocoapods # CocoaPods
```

**Important**: Re-run `make <target>` after pulling changes since the Xcode project is not committed.

### Dependency Management
This project supports three dependency managers:
- **Swift Package Manager** (recommended): Configured in `Package.swift`
- **Carthage**: Uses generated Xcode project in `Support/Carthage/`
- **CocoaPods**: Podspecs hosted at `https://github.com/readium/podspecs`

## Testing Strategy

### Unit Tests
- `Tests/SharedTests`: Tests for ReadiumShared models and utilities
- `Tests/StreamerTests`: Publication parsing tests with fixtures in `Tests/StreamerTests/Fixtures/`
- `Tests/NavigatorTests`: Navigator component tests
- `Tests/OPDSTests`: OPDS parsing tests
- `Tests/InternalTests`: Internal utilities tests
- `Tests/Publications`: Shared test publications used across test targets

### UI Tests
Navigator UI tests use a separate Xcode project:
```bash
make navigator-ui-tests-project
xcodebuild test -project Tests/NavigatorTests/UITests/NavigatorUITests.xcodeproj -scheme NavigatorTestHost -destination "platform=iOS Simulator,name=iPhone SE (3rd generation)"
```

### Test Fixtures
Test publications are in `Tests/Publications/Publications/` and `Tests/*/Fixtures/`. When adding tests, place fixtures in the appropriate directory.

## Module Organization

### Sources Structure
```
Sources/
├── Shared/          # Publication models, utilities (ReadiumShared)
│   ├── Publication/ # Publication, Manifest, Link, Locator, services
│   ├── Toolkit/     # HTTP client, archive handling, resources
│   └── OPDS/        # OPDS models
├── Streamer/        # Publication parsing (ReadiumStreamer)
│   └── Parser/      # Format-specific parsers (EPUB, PDF, audiobook, etc.)
├── Navigator/       # UI rendering (ReadiumNavigator)
│   ├── EPUB/        # EPUB navigator with WKWebView
│   ├── PDF/         # PDF navigator with PDFKit
│   ├── Audiobook/   # Audio player navigator
│   ├── Preferences/ # User preferences system
│   └── TTS/         # Text-to-speech
├── OPDS/            # OPDS feed parsing (ReadiumOPDS)
├── LCP/             # Readium LCP DRM (ReadiumLCP)
├── Adapters/        # Third-party library adapters
└── Internal/        # Internal utilities (ReadiumInternal)
```

## Working with Publications

### Opening a Publication
```swift
let assetRetriever = AssetRetriever(httpClient: httpClient)
let publicationOpener = PublicationOpener(
    parser: DefaultPublicationParser(
        httpClient: httpClient,
        assetRetriever: assetRetriever,
        pdfFactory: DefaultPDFDocumentFactory()
    )
)

let asset = try await assetRetriever.retrieve(url: url).get()
let publication = try await publicationOpener.open(
    asset: asset,
    allowUserInteraction: true  // Allow DRM credential prompts
).get()
```

### Publication Services
Access publication capabilities via services:
```swift
// Search
if let searchService = publication.findService(SearchService.self) {
    let results = try await searchService.search(query: "term")
}

// Content extraction
if let contentService = publication.findService(ContentService.self) {
    let content = try await contentService.content()
}

// Positions for pagination
if let positionsService = publication.findService(PositionsService.self) {
    let positions = try await positionsService.positions()
}
```

### Navigation
```swift
// Go to a specific location
await navigator.go(to: locator, options: .animated)

// Navigate by page/resource
await navigator.goForward(options: .animated)
await navigator.goBackward(options: .animated)

// Current position
let currentLocator = navigator.currentLocation
```

## CI/CD

GitHub Actions workflow (`.github/workflows/checks.yml`):
- **Build**: Builds and tests all packages
- **Navigator UI Tests**: Runs Navigator UI tests
- **Lint**: Checks Swift formatting and JavaScript formatting/linting
- **Integration Tests**: Tests with SPM, Carthage, and CocoaPods dependency managers

Uses Xcode 16.2 on macOS 14 with iPhone SE (3rd generation) simulator.

## Important Notes

- **SwiftFormat**: Always run `make format` before submitting PRs. The project uses `.swiftformat` configuration.
- **JavaScript Bundling**: After modifying EPUB navigator scripts, run `make scripts` to regenerate bundles.
- **Module Independence**: Readium packages are designed to work independently. Only include what you need.
- **DRM**: LCP support requires `R2LCPClient.framework` from EDRLab (contact@edrlab.org).
- **Carthage Project**: When modifying package structure, regenerate with `make carthage-project`.
- **Main Branch**: `develop` (not `main`)

## Resources

- [Getting Started Guide](docs/Guides/Getting%20Started.md)
- [Navigator Guide](docs/Guides/Navigator/Navigator.md)
- [Opening Publications](docs/Guides/Open%20Publication.md)
- [TTS Guide](docs/Guides/TTS.md)
- [LCP Integration](docs/Guides/Readium%20LCP.md)
- [Migration Guide](docs/Migration%20Guide.md)
