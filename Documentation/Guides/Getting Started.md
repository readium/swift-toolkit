# Getting started

The Readium Swift toolkit enables you to develop reading apps for iOS and iPadOS. It provides built-in support for multiple publication formats such as EPUB, PDF, audiobooks, and comics.

:warning: Readium offers only low-level tools. You are responsible for creating a user interface for reading and managing books, as well as a data layer to store the user's publications. The Test App is an example of such integration.

The toolkit is divided into separate packages that can be used independently.

### Main packages

* `R2Shared` contains shared `Publication` models and utilities.
* `R2Streamer` parses publication files (e.g. an EPUB) into a `Publication` object.
* `R2Navigator` renders the content of a publication.

### Specialized packages

* `ReadiumOPDS` parses [OPDS catalog feeds](https://opds.io) (both OPDS 1 and 2).
* `ReadiumLCP` downloads and decrypts [LCP-protected publications](https://www.edrlab.org/readium-lcp/).

### Adapters to third-party dependencies

* `ReadiumAdapterGCDWebServer` provides an HTTP server built with [GCDWebServer](https://github.com/swisspol/GCDWebServer).

## Overview of the shared models (`R2Shared`)

The Readium toolkit provides models used as exchange types between packages.

### Publication

`Publication` and its sub-components represent a single publication – ebook, audiobook or comic. It is loosely based on the [Readium Web Publication Manifest](https://readium.org/webpub-manifest/).

A `Publication` instance:

* holds the metadata of a publication, such as its author or table of contents,
* allows to read the contents of a publication, e.g. XHTML or audio resources,
* provides additional services, for example content extraction or text search

### Link

A [`Link` object](https://readium.org/webpub-manifest/#24-the-link-object) holds a pointer (URL) to a `Publication` resource along with additional metadata, such as its media type or title.

The `Publication` contains several `Link` collections, for example:

* `readingOrder` lists the publication resources arranged in the order they should be read.
* `resources` contains secondary resources necessary for rendering the `readingOrder`, such as an image or a font file.
* `tableOfContents` represents the table of contents as a tree of `Link` objects.

### Locator

A [`Locator` object](https://readium.org/architecture/models/locators/) represents a precise location in a publication resource in a format that can be stored and shared across reading systems. It is more accurate than a `Link` and contains additional information about the location, e.g. progression percentage, position or textual context.

`Locator` objects are used for various features, including:

* reporting the current progression in the publication
* saving bookmarks, highlights and annotations
* navigating search results

## Opening a publication (`R2Streamer`)

To retrieve a `Publication` object from a publication file like an EPUB or audiobook, begin by creating a `PublicationAsset` object used to read the file. Readium provides a `FileAsset` implementation for reading a publication stored on the local file system.

```swift
let file = URL(fileURLWithPath: "path/to/book.epub")
let asset = FileAsset(file: file)
```

Then, use a `Streamer` instance to parse the asset and create a `Publication` object.

```swift
let streamer = Streamer()

streamer.open(asset: asset, allowUserInteraction: false) { result in
    switch result {
    case .success(let publication):
        print("Opened \(publication.metadata.title)")
    case .failure(let error):
        alert(error.localizedDescription)
    case .cancelled:
        // The user cancelled the opening, for example by dismissing a password pop-up.
        break
    }
}
```

The `allowUserInteraction` parameter is useful when supporting a DRM like Readium LCP. It indicates if the toolkit can prompt the user for credentials when the publication is protected.

## Accessing the metadata of a publication

After opening a publication, you may want to read its metadata to insert a new entity into your bookshelf database, for instance. The `publication.metadata` object contains everything you need, including `title`, `authors` and the `published` date.

You can retrieve the publication cover using `publication.cover`. Avoid calling this from the main thread to prevent blocking the user interface.

## Rendering the publication on the screen (`R2Navigator`)

You can use a Readium navigator to present the publication to the user. The `Navigator` renders resources on the screen and offers APIs and user interactions for navigating the contents.

:warning: The `Navigator` does not have a user interface other than the view that displays the publication. The application is responsible for providing a user interface with bookmark buttons, a progress bar, etc.

The Readium toolkit ships with one `Navigator` implementation per [publication profile](https://readium.org/webpub-manifest/profiles/). You can use `publication.conformsTo()` to determine the profile of a publication.

| Profile     | Navigator                     | Formats                                                               |
|-------------|-------------------------------|-----------------------------------------------------------------------|
| `epub`      | `EPUBNavigatorViewController` | EPUB (`.epub`), Readium Web Publication (`.webpub`)                   |
| `pdf`       | `PDFNavigatorViewController`  | PDF (`.pdf`), LCP-protected PDF (`.lcpdf`)                            |
| `audiobook` | `AudioNavigator`              | Zipped Audio Book (`.zab`), Readium Audiobook (`.audiobook`, `.lcpa`) |
| `divina`    | `CBZNavigatorViewController`  | Zipped Comic Book (`cbz`), Readium Divina (`.divina`)                 |

```swift
if publication.conformsTo(.epub) {
    let navigator = try EPUBNavigatorViewController(
        publication: publication,
        initialLocation: lastReadLocation,
        httpServer: GCDHTTPServer.shared
    )

    hostViewController.present(navigator, animated: true)
}
```

:point_up: The HTTP server is used to serve the publication resources to the navigator's web views. You may use your own implementation, or the recommended `GCDHTTPServer` which is part of the `ReadiumAdapterGCDWebServer` package.

## Navigating the contents of the publication (`R2Navigator`)

The `Navigator` offers various `go` APIs for navigating the publication. For instance:

* to the previous or next pages: `navigator.goForward()` or `navigator.goBackward()`
* to a link from the `publication.tableOfContents` or `publication.readingOrder`: `navigator.go(to: link)`
* to a locator from a search result: `navigator.go(to: locator)`

## Saving and restoring the last read location (`R2Navigator`)

You can observe the current position in the publication by implementing a `NavigatorDelegate`.

```swift
navigator.delegate = MyNavigatorDelegate()

class MyNavigatorDelegate: NavigatorDelegate {

    override func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
        if let position = locator.locations.position {
            print("At position \(position) on \(publication.positions.count)")
        }
        if let progression = locator.locations.progression {
            return "Progression in the current resource: \(progression)%"
        }
        if let totalProgression = locator.locations.totalProgression {
            return "Total progression in the publication: \(progression)%"
        }

        // Save the position in your bookshelf database
        database.saveLastReadLocation(locator.jsonString)
    }
}
```

The `Locator` object may be serialized to JSON in your database, and deserialized to set the initial location when creating the navigator.

```swift
let lastReadLocation = Locator(jsonString: dabase.lastReadLocation())

let navigator = try EPUBNavigatorViewController(
    publication: publication,
    initialLocation: lastReadLocation,
    httpServer: GCDHTTPServer.shared
)
```
