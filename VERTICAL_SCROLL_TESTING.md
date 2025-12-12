# Testing Vertical Scroll Mode - Step by Step Guide

## Quick Test với TestApp

### 1. Mở TestApp

```bash
cd TestApp
make spm  # Hoặc make dev nếu test local changes
open TestApp.xcodeproj
```

### 2. Tìm file khởi tạo EPUBNavigatorViewController

Thường là trong `BookViewController.swift` hoặc `ReaderViewController.swift`.

### 3. Enable Vertical Scroll Mode

Thay đổi Configuration:

```swift
// TÌM CODE NÀY (hoặc tương tự):
let config = EPUBNavigatorViewController.Configuration(
    preferences: preferences,
    // ... other settings
)

// THAY BẰNG:
let config = EPUBNavigatorViewController.Configuration(
    preferences: preferences,
    verticalScrollMode: true,  // ⭐ ADD THIS LINE
    // ... other settings
)
```

### 4. Build và Run

```bash
# Build
Cmd + B

# Run on Simulator
Cmd + R
```

### 5. Test Scenarios

#### Scenario 1: Scroll Trong Chapter
1. Mở một EPUB book
2. Swipe **UP** (lên) trong chapter
3. Swipe **DOWN** (xuống) trong chapter
4. ✅ **Expected**: Content scroll smoothly trong chapter

#### Scenario 2: Snap Sang Chapter Tiếp Theo
1. Scroll xuống hết chapter (đến cuối)
2. Continue swipe **DOWN**
3. ✅ **Expected**: Smooth snap animation đến **đầu** chapter tiếp theo

#### Scenario 3: Snap Về Chapter Trước
1. Ở đầu chapter, swipe **UP**
2. ✅ **Expected**: Smooth snap animation đến **cuối** chapter trước đó

#### Scenario 4: Short Chapter (Ngắn Hơn Màn Hình)
1. Tìm một chapter ngắn
2. Swipe **DOWN**
3. ✅ **Expected**: Immediate snap to next chapter (không scroll vì chapter quá ngắn)

#### Scenario 5: Swipe Ngang (Không Hoạt Động)
1. Swipe **LEFT** hoặc **RIGHT**
2. ✅ **Expected**: Nothing happens (vertical mode only responds to vertical swipes)

## Debugging Tips

### Issue: Vẫn Swipe Ngang Được

**Cause**: PaginationView vẫn ở horizontal mode

**Fix**: Check rằng `layoutMode` được set đúng:

```swift
// EPUBNavigatorViewController.swift - makePaginationView()
view.layoutMode = config.verticalScrollMode ? .vertical : .horizontal
```

### Issue: Không Scroll Dọc Được Trong Chapter

**Cause**: WebView scroll bị disable

**Fix**: Check `setupWebView()` trong EPUBReflowableSpreadView:

```swift
if isVerticalScrollMode {
    scrollView.isScrollEnabled = true   // ⭐ Must be true
}
```

### Issue: Snap Không Smooth

**Cause**: PaginationView paging bị disable

**Fix**: PaginationView scrollView phải có `isPagingEnabled = true` khi ở vertical mode.

## Manual Code Placement Example

Nếu bạn không tìm thấy TestApp, đây là code hoàn chỉnh:

```swift
import UIKit
import ReadiumNavigator
import ReadiumShared

class TestVerticalScrollViewController: UIViewController {
    var navigator: EPUBNavigatorViewController?

    func openEPUB(at url: URL) async throws {
        // 1. Open publication
        let asset = try await assetRetriever.retrieve(url: url).get()
        let publication = try await publicationOpener.open(
            asset: asset,
            allowUserInteraction: false
        ).get()

        // 2. Configure with vertical scroll mode
        let config = EPUBNavigatorViewController.Configuration(
            preferences: EPUBPreferences(
                scroll: false  // Keep false!
            ),
            verticalScrollMode: true,  // ⭐ Enable vertical snap mode
            preloadNextPositionCount: 6,
            preloadPreviousPositionCount: 2
        )

        // 3. Create navigator
        navigator = try await EPUBNavigatorViewController(
            publication: publication,
            config: config,
            httpServer: httpServer
        )

        navigator?.delegate = self

        // 4. Add to view hierarchy
        guard let navigator = navigator else { return }
        addChild(navigator)
        view.addSubview(navigator.view)
        navigator.view.frame = view.bounds
        navigator.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigator.didMove(toParent: self)

        print("✅ Vertical Scroll Mode enabled!")
    }
}

extension TestVerticalScrollViewController: EPUBNavigatorDelegate {
    func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
        print("📍 Location changed: \(locator.href)")
    }

    func navigator(_ navigator: Navigator, didJumpTo locator: Locator) {
        print("⚡ Snapped to: \(locator.href)")
    }
}
```

## Expected Behavior Summary

| Action | Current Position | Expected Result |
|--------|-----------------|-----------------|
| Swipe UP | Middle of chapter | Scroll up within chapter |
| Swipe UP | Top of chapter | Snap to **end** of previous chapter |
| Swipe DOWN | Middle of chapter | Scroll down within chapter |
| Swipe DOWN | Bottom of chapter | Snap to **start** of next chapter |
| Swipe LEFT/RIGHT | Anywhere | No effect (vertical mode) |

## Troubleshooting Checklist

- [ ] `config.verticalScrollMode = true` đã set?
- [ ] `paginationView.layoutMode = .vertical` đã được apply?
- [ ] `scrollView.isScrollEnabled = true` trong WebView?
- [ ] EPUB là reflowable (không phải fixed-layout)?
- [ ] TestApp đã rebuild sau khi thay đổi code?

## Performance Monitoring

Trong Xcode Debug Navigator:

1. **Memory**: Should stay reasonable (~50-100MB for typical book)
2. **CPU**: Should be low when idle, spike only during snap animation
3. **Energy**: Should be "Low" or "Medium"

## Logs to Check

Enable logging to see navigation events:

```swift
// Add in viewDidLoad
print("🎯 Vertical Scroll Mode: \(config.verticalScrollMode)")
print("📐 Layout Mode: \(paginationView.layoutMode)")
```

Expected output:
```
🎯 Vertical Scroll Mode: true
📐 Layout Mode: vertical
📍 Location changed: chapter1.xhtml
⚡ Snapped to: chapter2.xhtml
📍 Location changed: chapter2.xhtml
```

## Known Limitations

1. ⚠️ **Only for Reflowable EPUBs**: Fixed-layout EPUBs not supported yet
2. ⚠️ **Don't mix with `scroll: true`**: Use either vertical scroll mode OR continuous scroll, not both
3. ⚠️ **RTL not fully tested**: Right-to-left publications might need adjustments

## Next Steps After Testing

If testing is successful:

1. Run `make format` to format code
2. Run `make test` to ensure no regressions
3. Consider submitting a PR to Readium upstream

## Questions?

Check these files for implementation details:
- [VERTICAL_SCROLL_FEATURE_REQUEST.md](VERTICAL_SCROLL_FEATURE_REQUEST.md) - Full documentation
- [EBOOK_DISPLAY_NAVIGATION_ANALYSIS.md](EBOOK_DISPLAY_NAVIGATION_ANALYSIS.md) - Architecture analysis
