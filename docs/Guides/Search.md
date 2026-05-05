# Searching a publication

The Search API lets you look for a textual query in the content of a `Publication`. EPUB and PDF publications are supported.

## Checking if a publication is searchable

Not every publication has a search service attached. Check **`isSearchable`** before offering a search UI.

```swift
guard publication.isSearchable else {
    // Hide or disable the search UI.
    return
}
```

## Performing a search

Call **`publication.search(query:options:)`** to start a new search. This method returns a **`SearchResult<SearchIterator>`** — either a cursor to page through results, or a **`SearchError`**.

```swift
let result = await publication.search(query: "red panda")

switch result {
case .success(let iterator):
    // Use the iterator to page through results.
case .failure(let error):
    handleSearchError(error)
}
```

## Iterating through results

The **`SearchIterator`** is a cursor that fetches results one page at a time. Each page is a **`LocatorCollection`** containing an array of **`Locator`** values, one per match.

Call **`iterator.next()`** to retrieve the next page. It returns `nil` on success when all results have been exhausted, or `.failure` if a read error occurs.

```swift
while let page = try await iterator.next().get() {
    for locator in page.locators {
        print("Found result at: \(locator.href)")
    }
}
```

To navigate directly to a result, pass the locator to the Navigator:

```swift
await navigator.go(to: locator)
```

### Pagination strategies

Results may arrive in pages to progressively load results. In practice there are two common approaches:

- **Background load:** start a `Task` that accumulates every result progressively. Simple to implement; the full list updates every time a new page is fetched.

- **On-scroll load:** hold onto the iterator and call `next()` only when the user scrolls to the bottom of the current batch. This keeps memory and CPU usage low, at the cost of slightly more state management.

### Grouping results by section

**`locator.title`** is the title of the table of contents entry that contains the match — for example, a chapter or section title. Use it to group consecutive results that fall within the same entry:

```swift
var sections: [(title: String?, locators: [Locator])] = []
for locator in page.locators {
    if locator.title == sections.last?.title {
        sections[sections.count - 1].locators.append(locator)
    } else {
        sections.append((title: locator.title, locators: [locator]))
    }
}
```

This preserves order and keeps sections with the same title distinct when they are not consecutive.

### Displaying a result snippet

**`locator.text`** contains the matched text and its surrounding context:

- `highlight` — the exact string that matched the query.
- `before` / `after` — a short snippet of text on either side of the match.

Here is a SwiftUI view that renders a single result with the matched text in bold:

```swift
struct SearchResultRow: View {
    let locator: Locator

    var body: some View {
        Text(snippet)
    }

    private var snippet: AttributedString {
        var result = AttributedString()
        if let before = locator.text?.before {
            result += AttributedString(before)
        }
        if let highlight = locator.text?.highlight {
            var bold = AttributedString(highlight)
            bold.font = .body.bold()
            result += bold
        }
        if let after = locator.text?.after {
            result += AttributedString(after)
        }
        return result
    }
}
```

In a real UI you will typically want to truncate `before` and `after` so the UI stays compact.

## Search options

Pass a **`SearchOptions`** value to `search(query:options:)` to override the defaults. Any option you leave as `nil` falls back to the default behavior.

```swift
let result = await publication.search(
    query: "Red Panda",
    options: SearchOptions(
        caseSensitive: true,
        diacriticSensitive: false
    )
)
```

The full set of available options:

| Option                | Type               | Built-in | Description                                                                       |
|-----------------------|--------------------|----------|-----------------------------------------------------------------------------------|
| `caseSensitive`       | `Bool?`            | Yes      | When `true`, the search distinguishes upper- and lower-case letters.              |
| `diacriticSensitive`  | `Bool?`            | Yes      | When `true`, accented and unaccented letters are treated as distinct.             |
| `wholeWord`           | `Bool?`            | No       | When `true`, only complete words are matched, not substrings.                     |
| `exact`               | `Bool?`            | Yes      | When `true`, the query is matched exactly, including stop words and word order.   |
| `language`            | `Language?`        | Yes      | Overrides the publication's language for this search.                             |
| `regularExpression`   | `Bool?`            | Yes      | When `true`, the query is interpreted as a regular expression.                    |
| `otherOptions`        | `[String: String]` | –        | Custom options specific to the search service implementation.                     |

The **Built-in** column indicates whether the default Readium configuration handles the option. Options marked **No** are silently ignored unless you provide a custom algorithm that implements them.

### Supported options

Before displaying search-option controls – e.g. a case sensitivity toggle, or regex mode – inspect **`publication.searchOptions`** to learn which options the service actually supports. An option whose value is `nil` is **not supported** by the current service; do not show it in the UI. The actual value indicates the default behavior when the option is not overridden.

```swift
let options = publication.searchOptions

// Only show the case-sensitivity toggle if the service supports it.
if let caseSensitive = options.caseSensitive {
    showCaseSensitiveToggle(defaultValue: caseSensitive)
}
```

## Error handling

**`SearchError`** describes what can go wrong:

- **`.publicationNotSearchable`** – The publication has no search service. Guard on `isSearchable` first.
- **`.badQuery(Error)`** – The query string is invalid. Not all implementations produce this; custom services may use it to signal a malformed query (for example, an invalid regular expression).
- **`.reading(ReadError)`** – An I/O error occurred while reading a resource.

```swift
switch searchError {
case .publicationNotSearchable:
    break // Should not happen if you check isSearchable first.
case .badQuery(let error):
    showAlert("Invalid query")
case .reading(let error):
    showAlert("Failed to read the publication resources")
}
```

## Advanced customization

### Configuring the search service

The default parsers automatically register **`ContentSearchService`** for EPUB and PDF publications, which relies on the [Content API](Content.md) to inspect the publication content. You do not need to do anything for the default behavior.

To customize the default service — for example, to adjust the snippet length or plug in a different search algorithm — override it in the `onCreatePublication` callback when opening a publication:

```swift
let result = await publicationOpener.open(
    asset: asset,
    allowUserInteraction: true,
    onCreatePublication: { _, _, services in
        services.setSearchServiceFactory(
            ContentSearchService.makeFactory(
                snippetLength: 300,
                searchAlgorithm: BasicStringSearchAlgorithm()
            )
        )
    }
)
```

The `snippetLength` parameter controls how many characters of context are included in the `before` and `after` text of each result's **`Locator.Text`**.

> [!NOTE]
> `ContentSearchService` depends on a `ContentService` being registered for the publication. This is set up automatically by the default parsers.

### Implementing a custom search algorithm

The actual text-matching logic is separated into the **`StringSearchAlgorithm`** protocol. You can swap it out without changing anything else about the service.

**`BasicStringSearchAlgorithm`** is the built-in implementation. It uses the native `String.range(of:options:)` APIs and supports `caseSensitive`, `diacriticSensitive`, `exact`, and `regularExpression`.

To use a custom algorithm, pass it to `ContentSearchService.makeFactory`:

```swift
ContentSearchService.makeFactory(searchAlgorithm: MyFuzzySearchAlgorithm())
```
