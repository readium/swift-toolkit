---
name: write-tests
description: Write Swift unit tests using Swift Testing (the modern Apple testing framework, not XCTest). Use this skill whenever the user asks to write tests, add test cases, create a test suite, or test a Swift type or function. Also triggers when the user asks to convert XCTest tests to Swift Testing, or when adding new tests to an existing XCTest-based file (always convert first). Invoke proactively when the user has just written a new Swift type or function and hasn't tested it yet.
---

# Write Tests

Write idiomatic Swift unit tests using Swift Testing.

## Non-negotiable: always Swift Testing

**Do not write XCTest.**

Even when the user doesn't mention a framework, use Swift Testing. XCTest is legacy. The only exception is UI tests, which still require XCTest.

If the user asks to add tests to an existing XCTest file, convert the whole file to Swift Testing first, then add the new tests.

A correct file always looks like this:

```swift
import Testing

struct FooTests {
    struct Something {
        @Test func returnsHelloWorld() {
            let foo = Foo()
            #expect(foo.something() == "Hello world")
        }
    }
}
```

## Suite structure

Organize tests in nested `struct` types. Each top-level suite covers one tested type.

**Never use `// MARK:` inside a test suite type.** Use a nested struct instead. A `// MARK:` at file scope (to label a helpers section at the bottom) is the only acceptable use.

```swift
// ✅ Correct — nested struct for organization
struct URLTests {

    struct Absolute {
        @Test func isUnchanged() { ... }
        @Test func withFragment() { ... }
    }

    struct Relative {
        @Test func resolution() { ... }
        @Test func withDotDot() { ... }
    }
}

// ❌ Wrong — MARK inside a suite type
struct URLTests {
    // MARK: - Absolute    ← must become `struct Absolute { ... }`
    @Test func isUnchanged() { ... }

    // MARK: - Relative    ← must become `struct Relative { ... }`
    @Test func resolution() { ... }
}
```

**`@Suite` annotation rules:**
- Omit `@Suite` entirely when the struct name already makes the suite's purpose clear. Swift Testing discovers it automatically.
- Add `@Suite` only to attach a **trait** (`.serialized`, `.disabled("reason")`), not to customize the display name.
- Specifically: `URLTests` does not need `@Suite`. `LocatorTests` does not need `@Suite`. Just write `struct URLTests {`.

**Naming:**
- Top-level suite: `<TypeName>Tests` (e.g. `LocatorTests`, `URLTests`)
- Nested suites: concept/API name only, **no `Tests` suffix** (e.g. `Absolute`, `Relative`, `Combining`, `ErrorHandling`)

## Declaring tests

```swift
// Basic
@Test func returnsNilForInvalidInput() { ... }

// Custom display name — only when the function name alone would be confusing
@Test("Parsing a locator with a fragment") func parseWithFragment() { ... }

// Parameterized — use instead of copying the same test body multiple times
@Test("All formats round-trip", arguments: Format.allCases)
func roundTrip(format: Format) throws { ... }

// Async/throws — just mark the function
@Test func fetchMetadata() async throws { ... }
```

## Assertions

| Goal                                     | Use                                         |
|------------------------------------------|---------------------------------------------|
| Verify a condition (continue on failure) | `#expect(condition)`                        |
| Verify and halt on failure               | `try #require(condition)`                   |
| Unwrap an optional or halt               | `let x = try #require(optional)`            |
| Expect a thrown error                    | `#expect(throws: MyError.self) { try ... }` |
| Unconditional failure                    | `Issue.record("reason")`                    |

**Use force unwrap (`!`) for values that must exist — don't use `guard ... else { return }`.** A crash on force unwrap produces a clear failure with a line number. A silent `return` makes the test pass incorrectly when a value is nil.

```swift
// ✅ Good
let url = URL(string: "https://example.com")!

// ❌ Bad — silently passes if url is nil
guard let url = URL(string: input) else { return }
```

## Setup and teardown

Use `init` / `deinit` instead of `setUp`/`tearDown`. Each test method gets a fresh instance of the suite struct, so `init` is sufficient.

```swift
struct DatabaseTests {
    let db: Database

    init() async throws {
        db = try await Database.makeInMemory()
    }
}
```

## Converting from XCTest — step by step

Given an XCTest file, apply these transformations in order:

1. Replace `import XCTest` → `import Testing`
2. Remove `: XCTestCase`, change `class` → `struct`
3. Remove `test` prefix from all method names
4. Replace `setUpWithError()` → `init() throws`, `tearDownWithError()` → `deinit` (on a class/actor)
5. Replace assertions: `XCTAssertEqual(a, b)` → `#expect(a == b)`, `XCTAssertNil(x)` → `#expect(x == nil)`, `XCTUnwrap(x)` → `try #require(x)`, `XCTFail("msg")` → `Issue.record("msg")`
6. Remove `continueAfterFailure = false` — use `try #require(...)` where needed
7. **Convert every `// MARK:` group inside the type into a nested struct:**

```swift
// Before (XCTest)
final class URLTests: XCTestCase {
    // MARK: - Absolute
    func testAbsoluteURLIsUnchanged() { XCTAssertEqual(...) }

    // MARK: - Relative
    func testRelativeURLResolution() { XCTAssertEqual(...) }
}

// After (Swift Testing)
struct URLTests {
    struct Absolute {
        @Test func absoluteURLIsUnchanged() { #expect(...) }
    }

    struct Relative {
        @Test func relativeURLResolution() { #expect(...) }
    }
}
```

Do not keep any `@Suite("...")` on the top-level struct — `struct URLTests` needs no annotation.

## Helpers

- Single-suite helpers: `fileprivate` functions at the bottom of the file. A `// MARK: - Helpers` at file scope (outside any suite type) is acceptable.
- Cross-suite helpers: `internal` free functions in a dedicated `TestHelpers.swift` file in the test target, or in their own files for mocks/fakes.
- Never use `static` helpers inside a test suite.

```swift
// At file scope, after all suite types

// MARK: - Helpers

fileprivate func makeLocator(href: String = "/ch.html", progression: Double? = nil) -> Locator {
    Locator(href: href, type: "text/html", locations: .init(progression: progression))
}
```

## Review checklist (fix before presenting)

1. Does every file start with `import Testing`? Zero `import XCTest`.
2. Happy path, boundary conditions, and error cases covered?
3. Similar tests collapsed into `@Test(arguments:)` parameterized tests?
4. No `// MARK:` inside any suite type?
5. No `@Suite` without a trait attached?
6. No `guard ... else { return }` — replaced with `!` or `try #require`?
7. Three or more tests sharing setup? Extract a `fileprivate` helper.

## Traits and advanced features

- `.serialized`: run a suite's tests sequentially (use only when tests share mutable state)
- `.disabled("reason")`: skip a test with a documented reason
- `@Test(.tags(.networking))`: tag for CI filtering
- `confirmation(...)`: for callback-based async events
- `#expect(processExitsWith: .failure) { ... }`: for testing `precondition`/`fatalError`
