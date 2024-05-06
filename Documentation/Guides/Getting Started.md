# Getting started

The Readium Swift toolkit enables you to develop reading apps for iOS and iPadOS. It provides built-in support for multiple publication formats such as EPUB, PDF, audiobooks, and comics.

:warning: Readium offers only low-level tools. You are responsible for creating a user interface for reading and managing books, as well as a data layer to store the user's publications. The Test App is an example of such integration.

## Design principles

The toolkit has been designed following these core tenets:

* **Modular**: It is divided into separate modules that can be used independently.
* **Extensible**: Integrators should be able to support a custom DRM, publication format or inject their own stylesheets without modifying the toolkit itself.
* **Opiniated**: We adhere to open standards but sometimes interpret them for practicality.

## Packages

### Main packages

* `R2Shared` contains shared `Publication` models and utilities.
* `R2Streamer` parses publication files (e.g. an EPUB) into a `Publication` object.
* [`R2Navigator` renders the content of a publication](Navigator/Navigator.md).

### Specialized packages

* `ReadiumOPDS` parses [OPDS catalog feeds](https://opds.io) (both OPDS 1 and 2).
* [`ReadiumLCP` downloads and decrypts LCP-protected publications](Readium%20LCP.md).

### Adapters to third-party dependencies

* `ReadiumAdapterGCDWebServer` provides an HTTP server built with [GCDWebServer](https://github.com/swisspol/GCDWebServer).

## Overview of the shared models (`R2Shared`)

The Readium toolkit provides models used as exchange types between packages.

### Publication models

#### Publication

`Publication` and its sub-components represent a single publication – ebook, audiobook or comic. It is loosely based on the [Readium Web Publication Manifest](https://readium.org/webpub-manifest/).

A `Publication` instance:

* holds the metadata of a publication, such as its author or table of contents,
* allows to read the contents of a publication, e.g. XHTML or audio resources,
* provides additional services, for example content extraction or text search.

#### Link


A [`Link` object](https://readium.org/webpub-manifest/#24-the-link-object) holds a pointer (URL) to a resource or service along with additional metadata, such as its media type or title.

The `Publication` contains several `Link` collections, for example:

* `readingOrder` lists the publication resources arranged in the order they should be read.
* `resources` contains secondary resources necessary for rendering the `readingOrder`, such as an image or a font file.
* `tableOfContents` represents the table of contents as a tree of `Link` objects.
* `links` exposes additional resources, such as a canonical link to the manifest or a search web service.

#### Locator

A [`Locator` object](https://readium.org/architecture/models/locators/) represents a precise location in a publication resource in a format that can be stored and shared across reading systems. It is more accurate than a `Link` and contains additional information about the location, e.g. progression percentage, position or textual context.

`Locator` objects are used for various features, including:

* reporting the current progression in the publication
* saving bookmarks, highlights and annotations
* navigating search results

### Data models

#### Publication Asset

A `PublicationAsset` is an interface representing a single file or package holding the content of a `Publication`. A default implementation `FileAsset` grants access to a publication stored locally.

#### Resource

A `Resource` provides read access to a single resource of a publication, such as a file or an entry in an archive.

`Resource` instances are usually created by a `Fetcher`. The toolkit ships with various implementations supporting different data access protocols such as local files, HTTP, etc.

#### Fetcher

A `Fetcher` provides read access to a collection of resources. `Fetcher` instances are created by a `PublicationAsset` to provide access to the content of a publication.

`Publication` objects internally use a `Fetcher` to expose their content.

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

```swift
let navigator = try EPUBNavigatorViewController(
    publication: publication,
    initialLocation: lastReadLocation,
    httpServer: GCDHTTPServer.shared
)

hostViewController.present(navigator, animated: true)
```
Please refer to the [Navigator guide](Navigator/Navigator.md) for more information.
