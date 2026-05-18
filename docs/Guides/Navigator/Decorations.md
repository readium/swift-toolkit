# Decorations

The Decoration API lets you overlay visual elements on publication content – highlights, search result markers, TTS playback indicators, page-number labels in the margin, and more. For the common case of implementing user highlights, see the [Highlighting guide](Highlights.md).

> [!NOTE]
> Only `EPUBNavigatorViewController` implements `DecorableNavigator` today. Always check if a navigator implements `DecorableNavigator` before enabling decoration-dependent features to future-proof your code.

## Overview

The Decoration API is built around a small set of types that work together.

### Decoration

A `Decoration` is a single UI element overlaid on publication content. It pairs a **location** (`Locator`) with a **style** (`Decoration.Style`) and carries a stable `id` used to track changes across updates.

A single logical entity can map to multiple Decoration objects. For example, a user annotation might use one decoration for the highlight and a second for a margin icon at the same location.

### Decoration Style

A `Decoration.Style` describes the *abstract appearance* of a decoration — for example, a semi-transparent highlight or an underline — independently of the underlying media type or rendering engine. The toolkit ships two built-in styles (`highlight` and `underline`) and lets you define your own  via `Decoration.Style.Id`.

#### Decoration Template (EPUB)

For EPUB, each `Decoration.Style.Id` maps to an `HTMLDecorationTemplate` that translates the abstract style into concrete HTML/CSS injected into the page.

### Decoration Group

Decorations are organised into **named groups**, one per logical app feature (e.g. `highlights`, `search`, `tts`, `page-list`, etc.). Each call to `apply(decorations:in:)` declares the complete desired state of one group; groups are fully independent. The navigator diffs the new list against the previous one internally and pushes only the necessary changes to the rendered content, so you can call `apply` on every state change without worrying about performance.

## Guides

### Creating a Decoration

A `Decoration` pairs a location in the publication with a style to render. The `id` must be unique within the group and should match your model's primary key—this is what lets you look up the underlying record when the user taps the decoration later.

```swift
let decoration = Decoration(
    id: highlight.id,
    locator: highlight.locator,
    style: .highlight(tint: highlight.color)
)
```

### Applying Decorations to the Navigator

Rather than telling the navigator about individual additions or removals, you declare the complete desired state of a group and let the navigator figure out what changed. Observe your models, map each one to a `Decoration`, then apply the full list:

```swift
let decorations = highlights.map { highlight in
    Decoration(
        id: highlight.id,
        locator: highlight.locator,
        style: .highlight(tint: highlight.color)
    )
}

navigator.apply(decorations: decorations, in: "highlights")
```

The navigator diffs the new list against the previous one and pushes only the actual changes to the rendered content. This means you can call `apply` freely on every state change — after an add, a color update, or a delete — without worrying about redundant work.

To clear a group entirely, apply an empty array:

```swift
navigator.apply(decorations: [], in: "highlights")
```

### Handling User Interactions on Decorations

Register a callback with `observeDecorationInteractions(inGroup:onActivated:)` to be notified when the user taps a decoration. The event carries the decoration itself, its group name, and the tap location in navigator view coordinates:

```swift
navigator.observeDecorationInteractions(inGroup: "highlights") { event in

}
```

**`event.decoration.id`** matches the id you set when creating the Decoration, so you can retrieve the corresponding model from your database.

**`event.rect`** gives the bounding box of the tapped decoration in the navigator view, useful for anchoring a popover.

### Checking Whether a Navigator Supports a Decoration Style

Not every navigator can render every style — underlining a sentence in an audiobook, for example, makes no sense. Before enabling a feature that depends on a specific style, verify that the navigator supports it:

```swift
if navigator.supports(decorationStyle: .underline) {
    // Offer underlining in the UI
}
```

For `EPUBNavigatorViewController`, this returns `true` for any style ID present in `Configuration.decorationTemplates`.

### Creating a Custom Decoration Style

The following example shows how to add a page-number label in the left margin for each entry in `publication.pageList` (declared print page markers).

#### 1. Declare a custom `Decoration.Style.Id`

```swift
extension Decoration.Style.Id {
    static let pageList: Decoration.Style.Id = "page-list"
}
```

#### 2. Define a config struct

The config carries the data your template needs. It must be `Hashable` so the diffing engine can detect changes.

```swift
struct PageListConfig: Hashable {
    /// Page number label from publication.pageList[].title
    var label: String   
}
```

#### 3. Write the `HTMLDecorationTemplate`

```swift
extension HTMLDecorationTemplate {
    static var pageList: HTMLDecorationTemplate {
        let className = "app-page-number"

        return HTMLDecorationTemplate(
            // One rectangle for the whole range
            layout: .bounds,    
            // Span the full page so the label can float left
            width: .page, 
            element: { decoration in
                let config = decoration.style.config as? PageListConfig

                // var(--RS__backgroundColor) matches the Readium CSS theme background.
                // Setting it inline prevents it being forced transparent by Readium CSS.
                return """
                    <div>
                        <span class="\(className)" style="background-color: var(--RS__backgroundColor) !important">
                            \(config?.label ?? "")
                        </span>
                    </div>
                """
            },
            stylesheet: """
                .\(className) {
                    float: left;
                    margin-left: 4px;
                    padding: 0px 2px 0px 2px;
                    border: 1px solid;
                    border-radius: 10%;
                    box-shadow: rgba(50, 50, 93, 0.25) 0px 2px 5px -1px, rgba(0, 0, 0, 0.3) 0px 1px 3px -1px;
                    opacity: 0.8;
                }
            """
        )
    }
}
```

#### 4. Register it in `Configuration.decorationTemplates`

```swift
var templates = HTMLDecorationTemplate.defaultTemplates()
templates[.pageList] = .pageList

let navigator = try EPUBNavigatorViewController(
    publication: publication,
    initialLocation: lastReadLocation,
    config: EPUBNavigatorViewController.Configuration(
        decorationTemplates: templates
    )
)
```

#### 5. Build and apply decorations

```swift
private func updatePageListDecorations() async {
    guard let navigator = navigator as? DecorableNavigator else { return }

    var decorations: [Decoration] = []
    for (index, link) in publication.pageList.enumerated() {
        guard
            let title = link.title,
            let locator = await publication.locate(link)
        else {
            continue
        }

        decorations.append(Decoration(
            id: "page-list-\(index)",
            locator: locator,
            style: Decoration.Style(
                id: .pageList,
                config: PageListConfig(label: title)
            )
        ))
    }

    navigator.apply(decorations: decorations, in: "page-list")
}
```

### Common Patterns

#### Search Results

Apply a temporary `"search"` group when the user performs a search. Use index-based IDs and `isActive` to highlight the currently selected result. Clear the group when the search is dismissed.

```swift
let navigator: DecorableNavigator

func applySearchDecorations(selectedIndex: Int?) {
    let decorations = searchResults.enumerated().map { index, result in
        Decoration(
            id: "\(index)",
            locator: result.locator,
            style: .highlight(isActive: index == selectedIndex)
        )
    }
    navigator.apply(decorations: decorations, in: "search")
}

// Show all results with none selected
applySearchDecorations(selectedIndex: nil)

// When the user moves to a result, mark it as active
applySearchDecorations(selectedIndex: currentResultIndex)

// Clear on dismiss
navigator.apply(decorations: [], in: "search")
```

#### TTS Playback

Track the currently spoken sentence with a single-decoration `"tts"` group. Replace the decoration each time TTS advances, and clear it when TTS stops.

```swift
let navigator: DecorableNavigator

func ttsDidStartSpeaking(locator: Locator) {
    let decoration = Decoration(
        id: "tts",
        locator: locator,
        style: .underline(tint: .red)
    )
    navigator.apply(decorations: [decoration], in: "tts")
}

func ttsDidStop() {
    navigator.apply(decorations: [], in: "tts")
}
```

## Further Reading

- [Readium Decorator API proposal](https://readium.org/architecture/proposals/008-decorator-api.html)
