# Opening a publication

To open a publication with Readium, you need to instantiate a couple of components: an `AssetRetriever` and a `PublicationOpener`.

## `AssetRetriever`

The `AssetRetriever` grants access to the content of an asset located at a given URL, such as a publication package, manifest, or LCP license.

### Constructing an `AssetRetriever`

You can create an instance of `AssetRetriever` with:

* An `HTTPClient` to enable the toolkit to perform HTTP requests and support the `http` and `https` URL schemes. You can use `DefaultHTTPClient` which provides callbacks for handling authentication when needed.

```swift
let assetRetriever = AssetRetriever(httpClient: DefaultHTTPClient())
```

### Retrieving an `Asset`

With your fresh instance of `AssetRetriever`, you can open an `Asset` from any `AbsoluteURL`.

```swift
// From a local file.
let url = FileURL(string: "file:///path/to/book.epub")
// or from an HTTP URL.
let url = HTTPURL(string: "https://domain/book.epub")

switch await assetRetriever.retrieve(url: url) {
    case .success(let asset):
        ...
    case .failure(let error):
        // Failed to retrieve the asset.
}
```

> [!IMPORTANT]
> Assets created with an HTTP URL are not downloaded; they will be streamed. If that is not your intention, you need to download the file first, for example using `HTTPClient.download()`.

The `AssetRetriever` will sniff the media type of the asset, which you can store in your bookshelf database to speed up the process next time you retrieve the `Asset`. This will improve performance, especially with HTTP URL schemes.

```swift
let mediaType = asset.format.mediaType

// Speed up the retrieval with a known media type.
let result = await assetRetriever.retrieve(url: url, mediaType: mediaType)
```

## `PublicationOpener`

`PublicationOpener` builds a `Publication` object from an `Asset` using:

* A `PublicationParser` to parse the asset structure and publication metadata.
    * The `DefaultPublicationParser` handles all the formats supported by Readium out of the box.
* An optional list of `ContentProtection` to decrypt DRM-protected publications.
    * If you support Readium LCP, you can get one from the `LCPService`.

```swift
let publicationOpener = PublicationOpener(
    parser: DefaultPublicationParser(
        httpClient: httpClient,
        assetRetriever: assetRetriever,
        pdfFactory: DefaultPDFDocumentFactory()
    ),
    contentProtections: [
        lcpService.contentProtection(with: LCPDialogAuthentication())
    ]
)
```

### Opening a `Publication`

Now that you have a `PublicationOpener` ready, you can use it to create a `Publication` from an `Asset` that was previously obtained using the `AssetRetriever`.

The `allowUserInteraction` parameter is useful when supporting Readium LCP. When enabled and using a `LCPDialogAuthentication`, the toolkit will prompt the user if the passphrase is missing.

```swift
let result = await publicationOpener.open(
    asset: asset,
    allowUserInteraction: true,
    sender: sender
)
```

## Supporting additional formats or URL schemes

`DefaultPublicationParser` accepts additional parsers. You also have the option to use your own parser list by using `CompositePublicationParser` or create your own `PublicationParser` for a fully customized parsing resolution strategy.

The `AssetRetriever` offers an additional constructor that provides greater extensibility options, using:

* `ResourceFactory` which handles the URL schemes through which you can access content.
* `ArchiveOpener` which determines the types of archives (ZIP, RAR, etc.) that can be opened by the `AssetRetriever`.
* `FormatSniffer` which identifies the file formats that `AssetRetriever` can recognize.

You can use either the default implementations or implement your own for each of these components using the composite pattern. The toolkit's `CompositeResourceFactory`, `CompositeArchiveOpener`, and `CompositeFormatSniffer` provide a simple resolution strategy.

