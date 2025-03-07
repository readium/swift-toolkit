# Getting started

The Readium Swift toolkit enables you to develop reading apps for iOS and iPadOS. It provides built-in support for multiple publication formats such as EPUB, PDF, audiobooks, and comics.

> [!NOTE]
> Readium offers only low-level tools. You are responsible for creating a user interface for reading and managing books, as well as a data layer to store the user's publications. The Test App is an example of such integration.

## Design principles

The toolkit has been designed following these core tenets:

* **Modular**: It is divided into separate modules that can be used independently.
* **Extensible**: Integrators should be able to support a custom DRM, publication format or inject their own stylesheets without modifying the toolkit itself.
* **Opiniated**: We adhere to open standards but sometimes interpret them for practicality.

## Packages

### Main packages

* `ReadiumShared` contains shared `Publication` models and utilities.
* `ReadiumStreamer` parses publication files (e.g. an EPUB) into a `Publication` object.
* [`ReadiumNavigator` renders the content of a publication](Navigator/Navigator.md).

### Specialized packages

* `ReadiumOPDS` parses [OPDS catalog feeds](https://opds.io) (both OPDS 1 and 2).
* [`ReadiumLCP` downloads and decrypts LCP-protected publications](Readium%20LCP.md).

### Adapters to third-party dependencies

* `ReadiumAdapterGCDWebServer` provides an HTTP server built with [GCDWebServer](https://github.com/swisspol/GCDWebServer).
* `ReadiumAdapterLCPSQLite` provides implementations of the `ReadiumLCP` license and passphrase repositories using [SQLite.swift](https://github.com/stephencelis/SQLite.swift).

## Overview of the shared models (`ReadiumShared`)

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

#### Asset

An `Asset` represents a single file or package and provides access to its content. There are two types of `Asset`:

* `ContainerAsset` for packages which contains several resources, such as a ZIP archive.
* `ResourceAsset` for accessing a single resource, such as a JSON or PDF file.

`Asset` instances are obtained through an `AssetRetriever`.

You can use the `asset.format` to identify the media type and capabilities of the asset.

```swift
if asset.format.conformsTo(.lcp) {
    // The asset is protected with LCP.
}
if asset.format.conformsTo(.epub) {
    // The asset represents an EPUB publication.
}
```

#### Resource

A `Resource` provides read access to a single resource, such as a file or an entry in an archive.

`Resource` instances are usually created by a `ResourceFactory`. The toolkit ships with various implementations supporting different data access protocols such as local files or HTTP.

#### Container

A `Container` provides read access to a collection of resources. `Container` instances representing an archive are usually created by an `ArchiveOpener`. The toolkit ships with a `ZIPArchiveOpener` supporting both local and remote (HTTP) ZIP files.

`Publication` objects internally use a `Container` to expose its content.

## Opening a publication (`ReadiumStreamer`)

To retrieve a `Publication` object from a publication file like an EPUB or audiobook, you can use an `AssetRetriever` and `PublicationOpener`.

```swift
// Instantiate the required components.
let httpClient = DefaultHTTPClient()
let assetRetriever = AssetRetriever(
    httpClient: httpClient
)
let publicationOpener = PublicationOpener(
    publicationParser: DefaultPublicationParser(
        httpClient: httpClient,
        assetRetriever: assetRetriever,
        pdfFactory: DefaultPDFDocumentFactory()
    )
)

let url: URL = URL(...)

// Retrieve an `Asset` to access the file content.
switch await assetRetriever.retrieve(url: url.anyURL.absoluteURL!) {
case .success(let asset):
    // Open a `Publication` from the `Asset`.
    switch await publicationOpener.open(asset: asset, allowUserInteraction: true, sender: view) {
    case .success(let publication):
        print("Opened \(publication.metadata.title)")

    case .failure(let error):
        // Failed to access or parse the publication
    }

case .failure(let error):
    // Failed to retrieve the asset
}
```

The `allowUserInteraction` parameter is useful when supporting a DRM like Readium LCP. It indicates if the toolkit can prompt the user for credentials when the publication is protected.

[See the dedicated user guide for more information](Open%20Publication.md).

## Accessing the metadata of a publication

After opening a publication, you may want to read its metadata to insert a new entity into your bookshelf database, for instance. The `publication.metadata` object contains everything you need, including `title`, `authors` and the `published` date.

You can retrieve the publication cover using `await publication.cover()`.

## Rendering the publication on the screen (`ReadiumNavigator`)

You can use a Readium navigator to present the publication to the user. The `Navigator` renders resources on the screen and offers APIs and user interactions for navigating the contents.

Please refer to the [Navigator guide](Navigator/Navigator.md) for more information.
