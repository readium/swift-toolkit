# 1. Render PDF decorations with overlay views, requiring iOS 16

## Context

The PDF navigator implements the [Decorator API](https://github.com/readium/architecture/blob/master/proposals/008-decorator-api.md) to render highlights, underlines and custom UI over a publication. Two rendering strategies were considered:

1. **`PDFAnnotation` mutation**: add annotation objects (e.g. `.highlight`) to the `PDFDocument` displayed by `PDFView`. Works since iOS 11.
2. **`PDFPageOverlayViewProvider` overlay views**: install a `UIView` over each page, which PDFKit keeps glued to the page through zoom and rotation. Requires iOS 16.

The `PDFDocument` displayed by the navigator is shared: it is cached by `PDFDocumentService` and can be reused by other components (search, content iteration) or by a second navigator instance. Mutating it with annotations would:

- leak transient UI state (highlights of one navigator session) into a shared model object;
- require careful bookkeeping to remove exactly the annotations we added, including after failures;
- conflict with documents that already contain author annotations;
- limit rendering to PDFKit's annotation appearance model, making custom templates (arbitrary views or CoreGraphics drawing) awkward.

Overlay views keep decorations purely in the view layer, support arbitrary `UIView`s and custom drawing, and are removed for free when the view hierarchy resets. Their downside is the iOS 16 floor, while the package still targets iOS 15.

## Decision

Use `PDFPageOverlayViewProvider` overlay views and gate the feature behind `#available(iOS 16, *)`. The shared cached `PDFDocument` is never mutated.

On iOS 15, `supports(decorationStyle:)` returns `false` and `apply(decorations:in:)` is a no-op that logs a warning, so a host app that skipped the `supports()` check isn't debugging an invisible highlight.

## Consequences

- Decorations don't render on iOS 15. Apps must check `supports(decorationStyle:)` before enabling decoration-based features, as the Decorator API already prescribes.
- `PDFDecorationTemplate` can vend arbitrary views (`.view`) or CoreGraphics drawing (`.draw`), which the annotation model couldn't offer.
- `.draw` templates are rasterized by the overlay's layer: the rasterization scale follows the zoom level up to a 4x cap, past which the drawing gets blurry. The built-in templates use solid-color `.view`s, which stay sharp at any zoom.
- When the iOS 15 floor is eventually dropped, the availability gates can be removed without changing the rendering architecture.
