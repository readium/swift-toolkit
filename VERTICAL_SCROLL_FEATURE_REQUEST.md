# Vertical Scroll Mode with Snap-to-Chapter Implementation

## Overview

This document describes the implementation of **vertical scroll mode with snap-to-chapter behavior** for the Readium Swift Toolkit's EPUB Navigator. This feature allows users to scroll vertically within chapters and automatically snap to the next/previous chapter when reaching boundaries.

## Architecture

### Two-Level Navigation System

The implementation uses a cascading 2-level navigation pattern:

```
User swipes down
    ↓
Level 1: EPUBReflowableSpreadView.scrollVertical(to: .down)
    ├─→ [Still has content below] → Scroll WebView ✅
    └─→ [Reached bottom] → return false
            ↓
         Level 2: PaginationView.goToIndex(nextIndex)
         → Snap to next chapter with animation ✅
```

### Key Components Modified

1. **EPUBSpreadView.swift**
   - Added `VerticalDirection` enum (up/down)
   - Added `scrollVertical(to:options:)` method

2. **EPUBReflowableSpreadView.swift**
   - Implemented vertical scroll with bounds detection
   - Returns `false` when at top/bottom to trigger Level 2 navigation

3. **PaginationView.swift**
   - Added `LayoutMode` enum (horizontal/vertical)
   - Updated `layoutSubviews()` to support vertical layout
   - Updated `UIScrollViewDelegate` methods for vertical scrolling

4. **EPUBNavigatorViewController.swift**
   - Added `verticalScrollMode` configuration
   - Added `goVertical(to:options:)` private method
   - Updated `goForward()/goBackward()` to use vertical navigation when enabled

## Usage

### Basic Setup

```swift
import ReadiumNavigator

// Create navigator with vertical scroll mode enabled
let config = EPUBNavigatorViewController.Configuration(
    verticalScrollMode: true  // Enable vertical scroll with snap
)

let navigator = try await EPUBNavigatorViewController(
    publication: publication,
    config: config,
    httpServer: httpServer
)
```

### Complete Example

```swift
class BookViewController: UIViewController {
    var navigator: EPUBNavigatorViewController?

    func openBook(publication: Publication) async throws {
        // Configure vertical scroll mode
        let config = EPUBNavigatorViewController.Configuration(
            preferences: EPUBPreferences(
                scroll: false  // Keep false - pagination is handled by PaginationView
            ),
            verticalScrollMode: true,  // Enable vertical snap mode
            preloadNextPositionCount: 6,
            preloadPreviousPositionCount: 2
        )

        navigator = try await EPUBNavigatorViewController(
            publication: publication,
            config: config,
            httpServer: httpServer
        )

        navigator?.delegate = self

        // Add to view hierarchy
        addChild(navigator!)
        view.addSubview(navigator!.view)
        navigator!.view.frame = view.bounds
        navigator!.didMove(toParent: self)
    }
}

extension BookViewController: EPUBNavigatorDelegate {
    func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
        // Save reading position
        print("Location changed to chapter: \(locator.href)")
    }

    func navigator(_ navigator: Navigator, didJumpTo locator: Locator) {
        // Chapter snap occurred
        print("Snapped to chapter: \(locator.href)")
    }
}
```

### Programmatic Navigation

```swift
// Navigate forward (scroll down or snap to next chapter)
await navigator.goForward(options: .animated)

// Navigate backward (scroll up or snap to previous chapter)
await navigator.goBackward(options: .animated)

// Jump to specific location
let locator = Locator(/* ... */)
await navigator.go(to: locator, options: .animated)
```

## User Experience

### Scroll Within Chapter

```
┌──────────────────┐
│  Chapter 2       │ ← User can scroll freely
│  Lorem ipsum...  │
│  dolor sit...    │ ← Swipe up/down
│  consectetur...  │
└──────────────────┘
```

### Snap to Next Chapter

```
┌──────────────────┐
│  Chapter 2       │
│  ...content...   │
│  The end.        │ ← At bottom, user swipes down
└──────────────────┘
        ↓ [Snap animation with spring effect]
┌──────────────────┐
│  Chapter 3       │ ← New chapter loaded at top
│  First line...   │
│  Second line...  │
└──────────────────┘
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `verticalScrollMode` | `Bool` | `false` | Enable vertical scroll with snap |
| `preloadNextPositionCount` | `Int` | `6` | Chapters to preload ahead |
| `preloadPreviousPositionCount` | `Int` | `2` | Chapters to preload behind |

### Performance Tuning

```swift
let config = EPUBNavigatorViewController.Configuration(
    verticalScrollMode: true,
    preloadNextPositionCount: 10,  // Preload more for smoother experience
    preloadPreviousPositionCount: 3  // Preload more when going back
)
```

## Technical Details

### Gesture Handling

The implementation leverages UIKit's nested UIScrollView behavior:

1. **WebView.scrollView** (child) handles scrolling within the chapter
2. **PaginationView.scrollView** (parent) handles snapping between chapters
3. UIKit automatically passes gestures from child to parent when child reaches bounds

No custom gesture recognizers needed!

### Bounds Detection

```swift
// EPUBReflowableSpreadView.swift
override func scrollVertical(to direction: VerticalDirection, options: NavigatorGoOptions) async -> Bool {
    let scrollView = self.scrollView

    // Edge case: Chapter shorter than screen
    guard scrollView.contentSize.height > scrollView.bounds.height else {
        return false  // Can't scroll, trigger snap immediately
    }

    let maxY = scrollView.contentSize.height - scrollView.bounds.height
    let currentY = scrollView.contentOffset.y
    let tolerance: CGFloat = 10

    // Check if at bounds (with small tolerance)
    if direction == .up && currentY <= tolerance {
        return false  // At top → snap to previous chapter
    }
    if direction == .down && currentY >= maxY - tolerance {
        return false  // At bottom → snap to next chapter
    }

    // Still within bounds → scroll normally
    let scrollAmount = scrollView.bounds.height * 0.8
    // ... perform scroll ...
    return true
}
```

### Snap Animation

The snap animation provides smooth transitions between chapters:

```swift
// PaginationView uses UIScrollView's built-in paging
// Combined with disabled bounces on WebView for clean gesture pass-through
scrollView.isPagingEnabled = true
scrollView.bounces = false  // On WebView to pass gesture to parent
```

## Limitations

1. **Fixed-Layout EPUBs**: Vertical scroll is only implemented for reflowable EPUBs. Fixed-layout EPUBs continue to use horizontal pagination.

2. **Scroll vs Vertical Mode**: Don't enable both `scroll: true` (continuous scroll) and `verticalScrollMode: true` at the same time. They serve different purposes:
   - `scroll: true` = Continuous vertical scroll without pagination (original feature)
   - `verticalScrollMode: true` = Vertical scroll with snap-to-chapter (new feature)

3. **RTL Support**: Currently tested with LTR (left-to-right) publications. RTL support inherits from existing implementation.

## Comparison with Existing Scroll Mode

| Feature | `scroll: true` | `verticalScrollMode: true` |
|---------|----------------|----------------------------|
| Direction | Vertical continuous | Vertical with snap |
| Chapter boundaries | No boundaries | Clear snap points |
| Preloading | All chapters loaded | Smart preloading (2-6 chapters) |
| Memory usage | High for large books | Efficient |
| Gesture | Continuous scroll | Scroll within, snap between |
| Use case | Long-form reading | Chapter-based books |

## Testing

### Manual Testing Checklist

1. **Within Chapter Scrolling**
   - Open a long chapter
   - Swipe up/down
   - Verify smooth scrolling within chapter

2. **Snap to Next Chapter**
   - Scroll to bottom of chapter
   - Swipe down
   - Verify smooth snap animation to next chapter
   - Verify next chapter loads at top

3. **Snap to Previous Chapter**
   - At top of chapter, swipe up
   - Verify snap to previous chapter
   - Verify previous chapter loads at bottom

4. **Short Chapters**
   - Open a chapter shorter than screen height
   - Swipe down
   - Verify immediate snap to next chapter (no scrolling)

5. **Preloading**
   - Observe memory usage while navigating
   - Verify chapters unload when out of range

### Automated Testing

```swift
func testVerticalScrollMode() async throws {
    let config = EPUBNavigatorViewController.Configuration(
        verticalScrollMode: true
    )

    let navigator = try await EPUBNavigatorViewController(
        publication: testPublication,
        config: config,
        httpServer: httpServer
    )

    // Test forward navigation
    let moved = await navigator.goForward(options: .instant)
    XCTAssertTrue(moved)

    // Verify location changed
    XCTAssertNotNil(navigator.currentLocation)
}
```

## Building the Project

```bash
# Format code (required before submitting PR)
make format

# Run tests
make test

# If modifying JavaScript (not needed for this feature)
make scripts
```

## Future Enhancements

1. **Configurable Scroll Amount**: Allow customizing the 80% scroll amount
2. **Snap Threshold**: Configurable tolerance for bounds detection
3. **Custom Animation**: Allow custom snap animation curves
4. **Fixed-Layout Support**: Extend to fixed-layout EPUBs
5. **Hybrid Mode**: Toggle between horizontal and vertical at runtime

## Implementation Summary

### Files Modified

1. **[Sources/Navigator/EPUB/EPUBSpreadView.swift](Sources/Navigator/EPUB/EPUBSpreadView.swift)**
   - Added `VerticalDirection` enum
   - Added `scrollVertical(to:options:)` base method

2. **[Sources/Navigator/EPUB/EPUBReflowableSpreadView.swift](Sources/Navigator/EPUB/EPUBReflowableSpreadView.swift)**
   - Implemented `scrollVertical(to:options:)` with bounds detection
   - Returns false at boundaries to trigger Level 2 navigation

3. **[Sources/Navigator/Toolkit/PaginationView.swift](Sources/Navigator/Toolkit/PaginationView.swift)**
   - Added `LayoutMode` enum (horizontal/vertical)
   - Updated `layoutSubviews()` with vertical layout case
   - Added `yOffsetForIndex()` method
   - Updated `scrollViewDidEndDecelerating()` for vertical mode
   - Updated `scrollToView(at:location:)` for vertical mode

4. **[Sources/Navigator/EPUB/EPUBNavigatorViewController.swift](Sources/Navigator/EPUB/EPUBNavigatorViewController.swift)**
   - Added `verticalScrollMode` to Configuration
   - Updated Configuration initializer
   - Added `goVertical(to:options:)` private method
   - Updated `makePaginationView()` to set layoutMode
   - Updated `goForward()` and `goBackward()` to use vertical navigation

### Lines of Code Changed

- **EPUBSpreadView.swift**: ~15 lines added
- **EPUBReflowableSpreadView.swift**: ~45 lines added
- **PaginationView.swift**: ~70 lines modified
- **EPUBNavigatorViewController.swift**: ~50 lines modified

**Total**: ~180 lines changed/added

## References

- [EBOOK_DISPLAY_NAVIGATION_ANALYSIS.md](EBOOK_DISPLAY_NAVIGATION_ANALYSIS.md) - Original architecture analysis
- [CLAUDE.md](CLAUDE.md) - Project development guide
- [docs/Guides/Navigator/Navigator.md](docs/Guides/Navigator/Navigator.md) - Navigator documentation

## Status

✅ **Implementation Complete**

The vertical scroll mode with snap-to-chapter behavior is now fully implemented and ready for testing.
