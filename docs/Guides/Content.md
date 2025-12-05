# Extracting the content of a publication

> [!NOTE]
> The described feature is still experimental and the implementation incomplete.

Many high-level features require access to the raw content (text, media, etc.) of a publication, such as:

* Text-to-speech
* Accessibility reader
* Basic search
* Full-text search indexing
* Image or audio indexes

The `ContentService` provides a way to iterate through a publication's content, extracted as semantic elements.

First, request the publication's `Content`, starting from a given `Locator`. If the locator is missing, the `Content` will be extracted from the beginning of the publication.

```swift
guard let content = publication.content(from: startLocator) else {
    // Abort as the content cannot be extracted
    return
}
```

## Extracting the raw text content

Getting the whole raw text of a publication is such a common use case that a helper is available on `Content`:

```swift
let wholeText = content.text()
```

This is an expensive operation, proceed with caution and cache the result if you need to reuse it.

## Iterating through the content

The individual `Content` elements can be iterated through with a regular `for` loop by converting it to a sequence:

```swift
for (element in content.sequence()) {
    // Process element
}
```

Alternatively, you can get the whole list of elements with `content.elements()`, or use the lower level APIs to iterate the content manually:

```swift
let iterator = content.iterator()
while let element = try iterator.next() {
    print(element)
}
```

Some `Content` implementations support bidirectional iterations. To iterate backwards, use:

```swift
let iterator = content.iterator()
while let element = try iterator.previous() {
    print(element)
}
```

## Processing the elements

The `Content` iterator yields `ContentElement` objects representing a single semantic portion of the publication, such as a heading, a paragraph or an embedded image.

Every element has a `locator` property targeting it in the publication. You can use the locator, for example, to navigate to the element or to draw a `Decoration` on top of it.

```swift
navigator.go(to: element.locator)
```

### Types of elements

Depending on the actual implementation of `ContentElement`, more properties are available to access the actual data. The toolkit ships with a number of default implementations for common types of elements.

#### Embedded media

The `EmbeddedContentElement` protocol is implemented by any element referencing an external resource. It contains an `embeddedLink` property you can use to get the actual content of the resource.

```swift
if let element = element as? EmbeddedContentElement {
    let bytes = try publication
        .get(element.embeddedLink)
        .read().get()
}
```

Here are the default available implementations:

* `AudioContentElement` - audio clips
* `VideoContentElement` - video clips
* `ImageContentElement` - bitmap images, with the additional property:
    * `caption: String?` - figure caption, when available

#### Text

##### Textual elements

The `TextualContentElement` protocol is implemented by any element which can be represented as human-readable text. This is useful when you want to extract the text content of a publication without caring for each individual type of elements.

```swift
let wholeText = publication.content()
    .elements()
    .compactMap { ($0 as? TextualContentElement)?.text.takeIf { !$0.isEmpty } }
    .joined(separator: "\n")
```

##### Text elements

Actual text elements are instances of `TextContentElement`, which represent a single block of text such as a heading, a paragraph or a list item. It is comprised of a `role` and a list of `segments`.

The `role` is the nature of the text element in the document. For example a heading, body, footnote or a quote. It can be used to reconstruct part of the structure of the original document.

A text element is composed of individual segments with their own `locator` and `attributes`. They are useful to associate attributes with a portion of a text element. For example, given the HTML paragraph:

```html
<p>It is pronounced <span lang="fr">croissant</span>.</p>
```

The following `TextContentElement` will be produced:

```swift
TextContentElement(
    role: .body,
    segments: [
        TextContentElement.Segment(text: "It is pronounced "),
        TextContentElement.Segment(text: "croissant", attributes: [ContentAttribute(key: .language, value: "fr")]),
        TextContentElement.Segment(text: ".")
    ]
)
```

If you are not interested in the segment attributes, you can also use `element.text` to get the concatenated raw text.

### Element attributes

All types of `ContentElement` can have associated attributes. Custom `ContentService` implementations can use this as an extensibility point.

## Use cases

### An index of all images embedded in the publication

This example extracts all the embedded images in the publication and displays them in a SwiftUI list. Clicking on an image jumps to its location in the publication.

```swift
struct ImageIndex: View {
    struct Item: Hashable {
        let locator: Locator
        let text: String?
        let image: UIImage
    }

    let publication: Publication
    let navigator: Navigator
    @State private var items: [Item] = []

    init(publication: Publication, navigator: Navigator) {
        self.publication = publication
        self.navigator = navigator
    }

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(items, id: \.self) { item in
                    VStack() {
                        Image(uiImage: item.image)
                        Text(item.text ?? "No caption")
                    }
                    .onTapGesture {
                        navigator.go(to: item.locator)
                    }
                }
            }
        }
        .onAppear {
            items = publication.content()?
                .elements()
                .compactMap { element in
                    guard
                        let element = element as? ImageContentElement,
                        let image = try? publication.get(element.embeddedLink)
                            .read().map(UIImage.init).get()
                    else {
                        return nil
                    }

                    return Item(
                        locator: element.locator,
                        text: element.caption ?? element.accessibilityLabel,
                        image: image
                    )
                }
                ?? []
        }
    }
}
```

## References

* [Content Iterator proposal](https://github.com/readium/architecture/pull/177)
