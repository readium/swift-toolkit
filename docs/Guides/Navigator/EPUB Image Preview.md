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

| Property                | Type          | Description                                                                                 |
|-------------------------|---------------|---------------------------------------------------------------------------------------------|
| `embeddedLink`          | **`Link`**    | Points to the image resource in the publication                                             |
| `caption`               | **`String?`** | Caption from the enclosing figure's `<figcaption>` element                                  |
| `accessibleName`        | **`String?`** | Accessible name, computed following [accname-1.2](https://www.w3.org/TR/accname-1.2)        |
| `accessibleDescription` | **`String?`** | Accessible description, computed following [accname-1.2](https://www.w3.org/TR/accname-1.2) |
| `extendedDescriptions`  | **`[Link]`**  | Links to extended descriptions, declared with [`aria-details`](https://daisy.github.io/transitiontoepub/best-practices/extended-desc/ExtendedDescriptionsBestPractices.html) |

The `text` property returns the `accessibleName`. To display a single text under the image, prefer the caption when available instead: `element.caption ?? element.accessibleName`. The caption and the accessible name can be the same string, when the `<figcaption>` also named an image which had no `alt` or `title` attribute. Coalesce them as above rather than concatenating them, or that image is labelled twice.

> [!NOTE]
> **`SVGContentElement`** follows a similar shape for inline SVG (`<svg>`), but exposes a `svg: String` property with the raw SVG source instead of `embeddedLink`. SVG images referenced via `<img src="...svg">` are reported as **`ImageContentElement`**.

### Extended descriptions

When the publication attaches [extended descriptions](https://daisy.github.io/transitiontoepub/best-practices/extended-desc/ExtendedDescriptionsBestPractices.html) to an image with `aria-details`, `extendedDescriptions` holds one `Link` per description. Each link points either at a separate resource of the publication, or at the description's container in the current resource (a fragment href). Its `title` comes from the target's `aria-label` or, for hyperlink targets, its text.

A good place to surface them is the image preview itself, as a "view extended description" action per link. To display one, navigate to it:

```swift
if
    let link = image.extendedDescriptions.first,
    let locator = await publication.locate(link)
{
    await navigator.go(to: locator)
}
```
