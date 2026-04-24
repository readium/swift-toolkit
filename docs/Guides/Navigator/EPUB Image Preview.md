# EPUB Image Preview

This guide explains how to detect when a user taps an image in an EPUB publication to present it in a dedicated view, using the `PointerEvent.targetElement` API.

> [!IMPORTANT]
> `targetElement` is an experimental API gated behind a Swift SPI. You must opt in at the import site and accept that the API may change in future releases.

## Detecting image taps

The EPUB Navigator populates `PointerEvent.targetElement` when it recognizes the content element under the pointer. The **`TargetElement`** value exposes two properties:

- `content` – the **`ContentElement`** under the pointer (e.g., **`ImageContentElement`**, **`SVGContentElement`**)
- `frame` – the element's on-screen `CGRect` relative to the navigator's view

Use the `.activate` observer (described in the [Input guide](Input.md)) to react to taps and clicks, then downcast `content` to the specific type you want to handle:

```swift
@_spi(ExperimentalTargetElement) import ReadiumNavigator

navigator.addObserver(.activate { event in
    guard
        let targetElement = event.targetElement,
        let image = targetElement.content as? ImageContentElement
    else {
        return false
    }
    // The user tapped an image – handle it here.
    return true
})
```

Returning `true` consumes the event, preventing other observers from handling the same tap.

## Working with `ImageContentElement`

**`ImageContentElement`** describes a bitmap image element and provides the following properties:

| Property             | Type          | Description                                                                    |
|----------------------|---------------|--------------------------------------------------------------------------------|
| `embeddedLink`       | **`Link`**    | Points to the image resource in the publication                                |
| `caption`            | **`String?`** | Caption extracted from a surrounding `<figcaption>` element or `alt` attribute |
| `accessibilityLabel` | **`String?`** | Accessibility label extracted from the `aria-label` attribute                  |

The `text` property returns the caption when available, otherwise the accessibility label — a convenient fallback when you need a single display string.

> [!NOTE]
> **`SVGContentElement`** follows a similar shape for inline SVG (`<svg>`), but exposes a `svg: String` property with the raw SVG source instead of `embeddedLink`. SVG images referenced via `<img src="...svg">` are reported as **`ImageContentElement`**.
