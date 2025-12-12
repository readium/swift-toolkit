# Phân tích cơ chế hiển thị và Navigation của Ebook

## 1. KIẾN TRÚC TỔNG QUAN

### 1.1. Các thành phần chính

```
┌─────────────────────────────────────────────────────────────┐
│                    EPUBNavigatorViewController               │
│  - Quản lý toàn bộ quá trình hiển thị và navigation        │
│  - State machine: initializing → loading → idle/jumping     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                       PaginationView                         │
│  - Container UIScrollView cho tất cả spreads                │
│  - Preload spreads thông minh (2 trước, 6 sau)             │
│  - Horizontal pagination với UIScrollViewDelegate           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              EPUBSpreadView (Abstract Base)                  │
│  - Đại diện cho 1 spread (1-2 trang liền kề)               │
│  - Quản lý WKWebView, JavaScript bridge, gestures           │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┴───────────────────┐
        ↓                                       ↓
┌─────────────────────────┐       ┌─────────────────────────┐
│ EPUBReflowableSpreadView│       │  EPUBFixedSpreadView    │
│  - Reflowable EPUB      │       │  - Fixed-layout EPUB    │
│  - CSS columns          │       │  - 1-2 pages side-by    │
│  - Horizontal scroll    │       │  - Zoom, pan support    │
└─────────────────────────┘       └─────────────────────────┘
```

### 1.2. Luồng dữ liệu

```
Publication (Model)
    ↓
EPUBNavigatorViewController.ViewModel
    ↓
PaginationView (spreads container)
    ↓
EPUBSpreadView[] (individual spreads)
    ↓
WKWebView[] (render HTML/CSS)
    ↓
JavaScript (handle interactions)
```

---

## 2. NAVIGATOR PROTOCOL

### 2.1. Giao diện chuẩn

Tất cả navigators (EPUB, PDF, Audio) đều implement protocol `Navigator`:

```swift
public protocol Navigator: AnyObject {
    /// Publication đang được hiển thị
    var publication: Publication { get }

    /// Vị trí hiện tại trong publication
    var currentLocation: Locator? { get }

    /// Di chuyển đến một vị trí cụ thể
    func go(to locator: Locator, options: NavigatorGoOptions) async -> Bool

    /// Di chuyển đến một link cụ thể
    func go(to link: Link, options: NavigatorGoOptions) async -> Bool

    /// Sang trang/resource tiếp theo
    func goForward(options: NavigatorGoOptions) async -> Bool

    /// Về trang/resource trước đó
    func goBackward(options: NavigatorGoOptions) async -> Bool
}
```

**File:** [Navigator.swift](Sources/Navigator/Navigator.swift)

### 2.2. Delegate callbacks

```swift
@MainActor public protocol NavigatorDelegate: AnyObject {
    /// Được gọi khi vị trí hiện tại thay đổi
    /// Nên lưu locator để restore lần đọc sau
    func navigator(_ navigator: Navigator, locationDidChange locator: Locator)

    /// Được gọi khi jump đến một vị trí (không liên tục)
    /// Dùng để implement navigation history
    func navigator(_ navigator: Navigator, didJumpTo locator: Locator)

    /// Được gọi khi có lỗi cần báo cho user
    func navigator(_ navigator: Navigator, presentError error: NavigatorError)

    /// Được gọi khi user tap external URL
    func navigator(_ navigator: Navigator, presentExternalURL url: URL)

    /// Được gọi khi user tap link đến note
    func navigator(_ navigator: Navigator, shouldNavigateToNoteAt link: Link,
                   content: String, referrer: String?) -> Bool

    /// Được gọi khi load resource thất bại
    func navigator(_ navigator: Navigator, didFailToLoadResourceAt href: RelativeURL,
                   withError error: ReadError)
}
```

**File:** [Navigator.swift:102-149](Sources/Navigator/Navigator.swift#L102-L149)

---

## 3. EPUB NAVIGATOR - STATE MACHINE

### 3.1. Các trạng thái

```swift
enum State {
    case initializing
    case loading(spreadIndex: Int)
    case idle
    case jumping(resource: Int, locator: Locator, options: NavigatorGoOptions)
    case moving(direction: Direction, options: NavigatorGoOptions)
}
```

**File:** EPUBNavigatorViewController.swift

### 3.2. Vòng đời state transitions

```
initializing
    ↓ (openPublication)
loading(spreadIndex: 0)
    ↓ (paginationViewDidLoad)
idle
    ↓ (user tap/swipe)
moving(direction, options)
    ↓ (animation completes)
idle

    OR

idle
    ↓ (go(to: locator))
jumping(resource, locator, options)
    ↓ (spread loaded, location set)
idle
```

### 3.3. Ví dụ navigation flow

**User swipe sang phải:**
```swift
1. User swipe → goForward() called
2. State: idle → moving(.forward, .animated)
3. PaginationView.goToIndex(currentIndex + 1)
4. Scroll animation
5. scrollViewDidEndDecelerating callback
6. State: moving → idle
7. updateCurrentLocation() → delegate.locationDidChange()
```

---

## 4. EPUB DISPLAY MECHANISM

### 4.1. Spread System

**Spread** = Đơn vị hiển thị cơ bản, chứa 1-2 trang liền kề

```swift
struct Spread {
    let leadingReadingOrderIndex: Int
    let trailingReadingOrderIndex: Int?

    var readingOrderIndices: [Int] {
        [leadingReadingOrderIndex] + (trailingReadingOrderIndex.map { [$0] } ?? [])
    }
}
```

**Ví dụ:**
- Spread 0: [page 0]
- Spread 1: [page 1, page 2]  // 2-page spread
- Spread 2: [page 3, page 4]

**File:** EPUBSpreadView.swift

### 4.2. EPUBSpreadView - Base Class

Mỗi spread được render trong một `EPUBSpreadView`:

```swift
class EPUBSpreadView: UIView {
    /// WebView chứa nội dung HTML
    let webView: WKWebView

    /// ScrollView wrapper của WebView
    var scrollView: UIScrollView { webView.scrollView }

    /// Spread data (reading order indices)
    let spread: Spread

    /// View model chứa publication metadata và settings
    let viewModel: EPUBNavigatorViewModel

    /// JavaScript ↔ Swift bridge
    func registerScriptMessages(in webView: WKWebView) {
        // Handle "spreadLoaded", "tap", "selectionChanged", etc.
    }

    /// Di chuyển đến vị trí trong spread
    func go(to location: PageLocation) async
}
```

**File:** [EPUBSpreadView.swift](Sources/Navigator/EPUB/EPUBSpreadView.swift)

### 4.3. EPUBReflowableSpreadView - Reflowable EPUB

**Đặc điểm:**
- Sử dụng CSS columns để tạo pagination
- Horizontal scroll giữa các columns
- Font size, spacing có thể thay đổi
- 1 spread = 1 HTML resource

**CSS pagination:**
```css
:root {
    --RS__colWidth: 100vw;
    --RS__colGap: 0px;
}

body {
    column-width: var(--RS__colWidth);
    column-gap: var(--RS__colGap);
    column-fill: auto;
}
```

**JavaScript bundled:** `index-reflowable.js`

**File:** [EPUBReflowableSpreadView.swift](Sources/Navigator/EPUB/EPUBReflowableSpreadView.swift)

### 4.4. EPUBFixedSpreadView - Fixed Layout EPUB

**Đặc điểm:**
- 1-2 HTML pages hiển thị side-by-side
- Không có CSS columns
- Zoom và pan support
- HTML wrapper: `fxl-spread-one.html` hoặc `fxl-spread-two.html`

**JavaScript bundled:** `index-fixed.js`, `index-fixed-wrapper-*.js`

**File:** EPUBFixedSpreadView.swift

---

## 5. PAGINATIONVIEW - CORE PAGINATION ENGINE

### 5.1. Nhiệm vụ chính

`PaginationView` là **UIScrollView container** quản lý tất cả spreads:

```swift
final class PaginationView: UIView {
    /// Tổng số spreads
    private(set) var pageCount: Int

    /// Spread hiện tại đang hiển thị
    private(set) var currentIndex: Int

    /// Dictionary chứa các spreads đã load
    private(set) var loadedViews: [Int: UIView & PageView]

    /// UIScrollView chứa tất cả spreads
    private let scrollView = UIScrollView()

    /// Hướng đọc (LTR/RTL)
    private(set) var readingProgression: ReadingProgression
}
```

**File:** [PaginationView.swift](Sources/Navigator/Toolkit/PaginationView.swift)

### 5.2. Layout mechanism

**Horizontal pagination:**

```swift
override func layoutSubviews() {
    let size = scrollView.bounds.size

    // Content size = width × số spreads
    scrollView.contentSize = CGSize(
        width: size.width * CGFloat(pageCount),
        height: size.height
    )

    // Layout từng spread
    for (index, view) in loadedViews {
        view.frame = CGRect(
            origin: CGPoint(x: xOffsetForIndex(index), y: 0),
            size: size
        )
    }

    // Scroll đến spread hiện tại
    scrollView.contentOffset.x = xOffsetForIndex(currentIndex)
}

private func xOffsetForIndex(_ index: Int) -> CGFloat {
    if readingProgression == .rtl {
        // RTL: spreads xếp từ phải sang trái
        return scrollView.contentSize.width - (CGFloat(index + 1) * scrollView.bounds.width)
    } else {
        // LTR: spreads xếp từ trái sang phải
        return scrollView.bounds.width * CGFloat(index)
    }
}
```

**File:** [PaginationView.swift:154-237](Sources/Navigator/Toolkit/PaginationView.swift#L154-L237)

### 5.3. Smart Preloading Strategy

**Position-based preloading** thay vì simple index-based:

```swift
// Configuration
preloadPreviousPositionCount: 2  // Load 2 positions trước
preloadNextPositionCount: 6      // Load 6 positions sau

// Ví dụ: Đang ở spread 5
// → Load spreads: 3, 4, [5], 6, 7, 8, 9, 10, 11
```

**Tại sao dùng position thay vì spread count?**
- Spreads có thể có length khác nhau (short chapter vs long chapter)
- Positions = uniform page units trong publication
- Đảm bảo preload đủ content cho smooth reading

**Thuật toán preloading:**

```swift
private func setCurrentIndex(_ index: Int, location: PageLocation? = nil) {
    currentIndex = index

    // Load theo thứ tự ưu tiên:
    // 1. Current spread (index)
    scheduleLoadPage(at: index, location: location)

    // 2. Next spreads (forward direction)
    let lastIndex = scheduleLoadPages(
        from: index,
        upToPositionCount: preloadNextPositionCount,
        direction: .forward,
        location: .start
    )

    // 3. Previous spreads (backward direction)
    let firstIndex = scheduleLoadPages(
        from: index,
        upToPositionCount: preloadPreviousPositionCount,
        direction: .backward,
        location: .end
    )

    // 4. Flush spreads ngoài range [firstIndex...lastIndex]
    for (i, view) in loadedViews {
        guard firstIndex...lastIndex ~= i else {
            view.removeFromSuperview()
            loadedViews.removeValue(forKey: i)
            continue
        }
    }

    loadPages()
}
```

**File:** [PaginationView.swift:263-293](Sources/Navigator/Toolkit/PaginationView.swift#L263-L293)

### 5.4. UIScrollViewDelegate callbacks

**Ngăn scroll quá nhiều spreads cùng lúc:**

```swift
func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                               withVelocity velocity: CGPoint,
                               targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    // Disable scroll ngay khi user nhả tay
    // → Chỉ scroll 1 spread mỗi lần
    scrollView.isScrollEnabled = false
}

func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    // Re-enable scroll sau khi animation xong
    scrollView.isScrollEnabled = isScrollEnabled

    // Tính spread mới từ contentOffset
    let currentOffset = (readingProgression == .rtl)
        ? scrollView.contentSize.width - (scrollView.contentOffset.x + scrollView.frame.width)
        : scrollView.contentOffset.x

    let newIndex = Int(round(currentOffset / scrollView.frame.width))
    setCurrentIndex(newIndex)  // → Trigger preloading
}
```

**File:** [PaginationView.swift:432-484](Sources/Navigator/Toolkit/PaginationView.swift#L432-L484)

---

## 6. NAVIGATION FLOWS

### 6.1. Level 1: Navigation trong cùng một Spread

**Áp dụng cho:** Reflowable EPUB với CSS columns

```swift
// EPUBReflowableSpreadView
override func go(to direction: EPUBSpreadView.Direction,
                 options: NavigatorGoOptions) async -> Bool {
    guard !viewModel.scroll else {
        return await super.go(to: direction, options: options)
    }

    // Tính offset mới
    let factor: CGFloat = (direction == .left) ? -1 : 1
    let offsetX = scrollView.bounds.width * factor
    var newOffset = scrollView.contentOffset
    newOffset.x += offsetX

    // Check xem còn trong spread không
    guard 0 ..< scrollView.contentSize.width ~= newOffset.x else {
        return false  // → Trigger Level 2 navigation
    }

    // Scroll đến column mới
    scrollView.setContentOffset(newOffset, animated: options.animated)
    return true
}
```

**Ví dụ:**
```
Spread 5 có 3 columns:
[Column A] [Column B] [Column C]
     ↑          ↑          ↑
  offset=0  offset=375  offset=750

User swipe right → offset: 0 → 375 → 750 → false (hết spread)
→ Return false → Trigger Level 2
```

**File:** [EPUBReflowableSpreadView.swift:172-204](Sources/Navigator/EPUB/EPUBReflowableSpreadView.swift#L172-L204)

### 6.2. Level 2: Navigation sang Spread mới

**Flow:**

```swift
// EPUBNavigatorViewController
func goForward(options: NavigatorGoOptions) async -> Bool {
    guard state == .idle else { return false }

    // 1. Thử Level 1 navigation trước
    if let currentView = paginationView.currentView {
        let moved = await currentView.go(to: .right, options: options)
        if moved {
            return true  // Success - vẫn trong spread
        }
    }

    // 2. Level 1 fail → Level 2 navigation
    state = .moving(direction: .forward, options: options)

    // 3. Load spread tiếp theo
    let nextIndex = paginationView.currentIndex + 1
    guard await paginationView.goToIndex(nextIndex,
                                         location: .start,
                                         options: options)
    else {
        state = .idle
        return false
    }

    // 4. Animation complete
    state = .idle
    return true
}
```

**File:** EPUBNavigatorViewController.swift

### 6.3. Jump Navigation (go to locator)

**Direct jump đến một vị trí bất kỳ:**

```swift
func go(to locator: Locator, options: NavigatorGoOptions) async -> Bool {
    // 1. Tìm resource index từ locator
    guard let index = viewModel.readingOrder.firstIndexWithHREF(locator.href) else {
        return false
    }

    // 2. Tìm spread index chứa resource đó
    guard let spreadIndex = viewModel.spreads.firstIndex(
        where: { $0.readingOrderIndices.contains(index) }
    ) else {
        return false
    }

    // 3. Jump state
    state = .jumping(resource: index, locator: locator, options: options)

    // 4. Load spread và navigate đến locator
    await paginationView.goToIndex(spreadIndex,
                                   location: .locator(locator),
                                   options: options)

    // 5. Notify delegate về discontinuous jump
    delegate?.navigator(self, didJumpTo: locator)

    state = .idle
    return true
}
```

---

## 7. LOCATOR SYSTEM

### 7.1. Locator structure

`Locator` = Vị trí chính xác trong publication

```swift
public struct Locator {
    /// Link đến resource (chapter/HTML file)
    public let href: RelativeURL

    /// Media type của resource
    public let mediaType: MediaType

    /// Tiêu đề hiển thị
    public let title: String?

    /// Thông tin vị trí
    public let locations: Locations

    /// Text context xung quanh vị trí
    public let text: Text
}

public struct Locations {
    /// Position trong publication (CFI, page number, etc.)
    public let position: Int?

    /// % tiến độ trong resource (0.0 - 1.0)
    public let progression: Double?

    /// Tổng số positions trong publication
    public let totalProgression: Double?

    /// Fragment identifier (e.g., #section-1)
    public let fragments: [String]
}
```

**File:** ReadiumShared/Publication/Locator.swift

### 7.2. Current location tracking

```swift
// EPUBNavigatorViewController
var currentLocation: Locator? {
    guard let spreadView = paginationView.currentView as? EPUBSpreadView else {
        return nil
    }
    return spreadView.currentLocator
}

// EPUBReflowableSpreadView
override var currentLocator: Locator? {
    // JavaScript call để lấy locator từ visible content
    let progression = scrollView.contentOffset.x / scrollView.contentSize.width

    return Locator(
        href: link.url(),
        mediaType: link.mediaType ?? .html,
        locations: Locator.Locations(
            progression: progression
        )
    )
}
```

---

## 8. JAVASCRIPT ↔ SWIFT BRIDGE

### 8.1. Message passing

**Swift → JavaScript:**
```swift
// EPUBSpreadView
func evaluateScript(_ script: String) async throws -> Any {
    return try await webView.evaluateJavaScript(script)
}

// Ví dụ: Scroll đến text
await evaluateScript("""
    readium.scrollToId('\(elementId)');
""")
```

**JavaScript → Swift:**
```swift
// EPUBSpreadView
func registerScriptMessages(in webView: WKWebView) {
    let handlers: [String: (Any) async -> Void] = [
        "spreadLoaded": { [weak self] _ in
            await self?.spreadDidLoad()
        },
        "tap": { [weak self] body in
            await self?.handleTapEvent(body)
        },
        "selectionChanged": { [weak self] body in
            await self?.handleSelectionChanged(body)
        }
    ]

    for (name, handler) in handlers {
        webView.addScriptMessageHandler(handler, name: name)
    }
}
```

**File:** EPUBSpreadView.swift

### 8.2. JavaScript files

**Reflowable EPUB:**
- `index-reflowable.js` - Main bundle
- Injected vào mỗi HTML resource
- Xử lý: pagination, gestures, selection, decorations

**Fixed Layout EPUB:**
- `index-fixed.js` - Page-level bundle
- `index-fixed-wrapper-one.js` - Single page wrapper
- `index-fixed-wrapper-two.js` - Double page wrapper

**Build command:**
```bash
cd Sources/Navigator/EPUB/Scripts/
make  # Bundle và embed vào app
```

**File location:** [Sources/Navigator/EPUB/Scripts/](Sources/Navigator/EPUB/Scripts/)

---

## 9. PREFERENCES SYSTEM

### 9.1. EPUBPreferences

User settings cho EPUB display:

```swift
public struct EPUBPreferences {
    // Typography
    public var fontFamily: FontFamily?
    public var fontSize: Double?
    public var fontWeight: Double?
    public var lineHeight: Double?
    public var letterSpacing: Double?
    public var wordSpacing: Double?
    public var paragraphSpacing: Double?

    // Layout
    public var pageMargins: Double?
    public var columnCount: ColumnCount?
    public var textAlign: TextAlignment?

    // Appearance
    public var theme: Theme?
    public var backgroundColor: Color?
    public var textColor: Color?

    // Reading mode
    public var scroll: Bool?  // false = paginated, true = continuous scroll
    public var spread: Spread?  // auto, never, always
}
```

**Apply preferences:**
```swift
navigator.submitPreferences(EPUBPreferences(
    fontSize: 1.5,
    theme: .sepia,
    scroll: false
))
```

**File:** ReadiumNavigator/EPUB/EPUBPreferences.swift

---

## 10. KEY DESIGN PATTERNS

### 10.1. State Machine Pattern

**EPUBNavigatorViewController** dùng state machine để tránh race conditions:
- Chỉ xử lý navigation khi ở state `idle`
- Transition states đảm bảo sequential operations
- Async/await cho clean async code

### 10.2. Delegation Pattern

**Loose coupling** giữa components:
- `PaginationViewDelegate` - Spread creation và lifecycle
- `NavigatorDelegate` - Navigation events cho app
- `EPUBSpreadViewDelegate` - Spread-specific events

### 10.3. Builder Pattern

**Publication.Builder** cho flexible construction:
```swift
let publication = Publication.Builder(
    manifest: manifest,
    servicesBuilder: servicesBuilder
).build()
```

### 10.4. Service Pattern

**PublicationService** cho modular features:
```swift
// Search service
if let searchService = publication.findService(SearchService.self) {
    let results = try await searchService.search(query: "term")
}

// Content service
if let contentService = publication.findService(ContentService.self) {
    let content = try await contentService.content()
}
```

---

## 11. PERFORMANCE OPTIMIZATIONS

### 11.1. Lazy Loading

- **Spreads loaded on-demand** theo position-based strategy
- **WebViews reused** khi có thể
- **Resources cached** trong memory và disk

### 11.2. Preloading Strategy

- **Asymmetric preloading**: 2 trước, 6 sau
- **Position-aware**: Load based on content length, not spread count
- **Flush old spreads**: Remove spreads outside visible range

### 11.3. Memory Management

```swift
override func willMove(toSuperview newSuperview: UIView?) {
    if newSuperview == nil {
        // Remove all spreads để break retain cycles
        for (_, view) in loadedViews {
            view.removeFromSuperview()
        }
        loadedViews.removeAll()
    }
}
```

---

## 12. TESTING

### 12.1. Unit Tests

```bash
# Run all tests
make test

# Test specific module
xcodebuild test -scheme "Readium-Package" \
    -destination "platform=iOS Simulator,name=iPhone SE (3rd generation)"
```

### 12.2. UI Tests

```bash
# Generate UI test project
make navigator-ui-tests-project

# Run UI tests
xcodebuild test \
    -project Tests/NavigatorTests/UITests/NavigatorUITests.xcodeproj \
    -scheme NavigatorTestHost \
    -destination "platform=iOS Simulator,name=iPhone SE (3rd generation)"
```

### 12.3. Test Publications

Test EPUBs located in:
- `Tests/Publications/Publications/`
- `Tests/StreamerTests/Fixtures/`

---

## 13. COMMON ISSUES & SOLUTIONS

### 13.1. Text truncation in WebView

**Issue:** Text bị cắt khi scroll

**Cause:** WebView content size chưa update đúng sau khi load

**Solution:** Wait for `spreadLoaded` message từ JavaScript trước khi navigate

### 13.2. Scroll position not restored

**Issue:** Khi rotate device hoặc switch apps, vị trí đọc bị mất

**Cause:** Không lưu currentLocation

**Solution:** Implement `locationDidChange` delegate:
```swift
func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
    // Save locator to UserDefaults/Database
    saveBookmark(locator)
}
```

### 13.3. Slow navigation

**Issue:** Lag khi lật trang

**Cause:** Chưa preload spreads đủ

**Solution:** Tăng `preloadNextPositionCount` trong config:
```swift
let config = EPUBNavigatorViewController.Configuration(
    preloadNextPositionCount: 10  // Default: 6
)
```

---

## 14. KEY DIFFERENCES: EPUB vs PDF

| Aspect | EPUB Navigator | PDF Navigator |
|--------|----------------|---------------|
| **Rendering** | WKWebView (HTML/CSS) | PDFKit (native) |
| **Pagination** | CSS columns hoặc fixed pages | Native PDF pages |
| **Reflow** | ✅ Yes (reflowable) | ❌ No |
| **Zoom** | Fixed (via CSS) | ✅ Full zoom/pan |
| **Text Selection** | JavaScript-based | Native PDFKit |
| **Annotations** | Custom decorations | Native PDF annotations |
| **Performance** | Good for text | Better for complex layouts |

---

## 15. MIGRATION NOTES

### 15.1. Từ version cũ (< 3.0)

**Breaking changes:**
- Navigator init changed from closure-based to async/await
- `currentPosition` → `currentLocation`
- Preferences system redesigned
- JavaScript bridge modernized

**Migration guide:** [docs/Migration Guide.md](docs/Migration%20Guide.md)

---

## 16. RESOURCES

### 16.1. Documentation

- [Getting Started Guide](docs/Guides/Getting%20Started.md)
- [Navigator Guide](docs/Guides/Navigator/Navigator.md)
- [Opening Publications](docs/Guides/Open%20Publication.md)
- [TTS Guide](docs/Guides/TTS.md)

### 16.2. Source Code Structure

```
Sources/Navigator/
├── Navigator.swift              # Protocol definition
├── EPUB/
│   ├── EPUBNavigatorViewController.swift
│   ├── EPUBSpreadView.swift
│   ├── EPUBReflowableSpreadView.swift
│   ├── EPUBFixedSpreadView.swift
│   ├── Scripts/                 # JavaScript bundles
│   └── Preferences/             # Settings system
├── PDF/
│   └── PDFNavigatorViewController.swift
├── Audiobook/
│   └── AudioNavigator.swift
└── Toolkit/
    └── PaginationView.swift     # Core pagination engine
```

### 16.3. Key Files Reference

| Component | File | Lines |
|-----------|------|-------|
| Navigator Protocol | Navigator.swift | ~155 |
| EPUB ViewController | EPUBNavigatorViewController.swift | ~800 |
| Pagination Engine | PaginationView.swift | ~514 |
| Reflowable Spread | EPUBReflowableSpreadView.swift | ~400 |
| Fixed Spread | EPUBFixedSpreadView.swift | ~600 |
| Spread Base | EPUBSpreadView.swift | ~500 |

---

## KẾT LUẬN

Readium Swift Toolkit sử dụng kiến trúc phân lớp rõ ràng:

1. **Navigator Protocol** - Unified interface
2. **EPUBNavigatorViewController** - State machine controller
3. **PaginationView** - Smart preloading container
4. **EPUBSpreadView** - WebView wrapper với JavaScript bridge
5. **JavaScript** - Runtime behavior và interactions

**Ưu điểm:**
✅ Modular và extensible
✅ Performance cao nhờ smart preloading
✅ Support cả reflowable và fixed-layout
✅ Preferences system linh hoạt
✅ Clean async/await API

**Best practices:**
- Luôn save `currentLocation` trong `locationDidChange`
- Config preload counts phù hợp với use case
- Test với nhiều loại EPUBs (reflowable, FXL, RTL)
- Monitor memory usage với large publications
