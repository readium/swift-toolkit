# Changelog

All notable changes to this project will be documented in this file. Take a look at [the migration guide](Documentation/Migration%20Guide.md) to upgrade between two major versions.

**Warning:** Features marked as *alpha* may change or be removed in a future release without notice. Use with caution.

## [Unreleased]

### Added

#### Shared

* [Extract the raw content (text, images, etc.) of a publication](Documentation/Guides/Content.md).

#### Navigator

* [A brand new text-to-speech implementation](Documentation/Guides/TTS.md).

### Deprecated

#### Shared

* `Locator(link: Link)` is deprecated as it may create an incorrect `Locator` if the link `type` is missing.
    * Use `publication.locate(Link)` instead.

### Fixed

#### Navigator

* Fixed memory leaks in the EPUB and PDF navigators.
* [#61](https://github.com/readium/swift-toolkit/issues/61) Fixed serving EPUB resources when the HREF contains an anchor or query parameters.
* Performance issue with EPUB fixed-layout when spreads are enabled.
* Disable scrolling in EPUB fixed-layout resources, in case the viewport is incorrectly set.

#### Streamer

* Fixed memory leak in the `PublicationServer`.

#### LCP

* The LCP authentication dialog is now fully localized and supports Dark Mode (contributed by [@openm1nd](https://github.com/readium/swift-toolkit/pull/50)).


## [2.3.0]

### Added

#### Shared

* Get the sanitized `Locator` text ready for user display with `locator.text.sanitized()`.
* A new `Publication.conforms(to:)` API to identify the profile of a publication.
* Support for the [`conformsTo` RWPM metadata](https://github.com/readium/webpub-manifest/issues/65), to identify the profile of a `Publication`.
* Support for right-to-left PDF documents by extracting the reading progression from the `ViewerPreferences/Direction` metadata.
* HTTP client:
    * A new `HTTPClient.download()` API to download HTTP resources to a temporary location.
    * `HTTPRequest` and `DefaultHTTPClient` take an optional `userAgent` property to customize the user agent. 

#### Navigator

* The new `NavigatorDelegate.navigator(_:didJumpTo:)` API is called every time the navigator jumps to an explicit location, which might break the linear reading progression.
    * For example, it is called when clicking on internal links or programmatically calling `Navigator.go(to:)`, but not when turning pages.
    * You can use this callback to implement a navigation history by differentiating between continuous and discontinuous moves.

### Deprecated

#### Shared

* `Publication.format` is now deprecated in favor of the new `Publication.conforms(to:)` API which is more accurate.
    * For example, replace `publication.format == .epub` with `publication.conforms(to: .epub)` before opening a publication with the `EPUBNavigatorViewController`.

### Changed

#### LCP

* The `LCPService` now uses a provided `HTTPClient` instance for all HTTP requests.

### Fixed

#### Navigator

* [#14](https://github.com/readium/swift-toolkit/issues/14) Backward compatibility (iOS 10+) of JavaScript files is now handled with Babel.
* Throttle the reload of EPUB spreads to avoid losing the position when the reader gets back to the foreground.

#### LCP

* Fixed the notification of acquisition progress.


## 2.2.0

### Added

#### Shared

* Support for Paragraph Margins user setting.

#### Navigator

* A new `translate` EPUB and PDF editing action is available for iOS 15.

### Fixed

#### Shared

* Improved performances of the search service used with EPUB.

#### Navigator

* Fixed turning pages of an EPUB reflowable resource with an odd number of columns. A virtual blank trailing column is appended to the resource when displayed as two columns.

## 2.1.1

### Fixed

#### LCP

* Fix crash using the default `LCPDialogViewController` with CocoaPods.


## 2.1.0

### Added

* Support for Swift Package Manager (contributed by [@stevenzeck](https://github.com/stevenzeck)).

#### Shared

* (*alpha*) A new Publication `SearchService` to search through the resources' content with a default implementation `StringSearchService`.
* `Link` objects from archive-based publication assets (e.g. an EPUB/ZIP) have additional properties for entry metadata.
    ```json
    "properties" {
        "archive": {
            "entryLength": 8273,
            "isEntryCompressed": true
        }
    }
    ```
* New `UserProperties.removeProperty(forReference:)` API to remove unwanted Readium CSS properties (contributed by [@ettore](https://github.com/readium/r2-shared-swift/pull/157)).

#### Navigator

* EPUB navigator:
    * The EPUB navigator is now able to navigate to a `Locator` using its `text` context. This is useful for search results or highlights missing precise locations.
    * New `EPUBNavigatorViewController.evaluateJavaScript()` API to run a JavaScript on the currently visible HTML resource.
    * New `userSettings` property for `EPUBNavigatorViewController.Configuration` to set the default user settings values (contributed by [@ettore](https://github.com/readium/r2-navigator-swift/pull/191)).
    * You can provide custom editing actions for the text selection menu (contributed by [@cbaltzer](https://github.com/readium/r2-navigator-swift/pull/181)).
        1. Create a custom action with, for example: `EditingAction(title: "Highlight", action: #selector(highlight:))`
        2. Then, implement the selector in one of your classes in the responder chain. Typically, in the `UIViewController` wrapping the navigator view controller.
        ```swift
        class EPUBViewController: UIViewController {
            init(publication: Publication) {
                var config = EPUBNavigatorViewController.Configuration()
                config.editingActions.append(EditingAction(title: "Highlight", action: #selector(highlight)))
                let navigator = EPUBNavigatorViewController(publication: publication, config: config)
            }

            @objc func highlight(_ sender: Any) {}
        }
        ```
* New `SelectableNavigator` protocol for navigators supporting user selection.
    * Get or clear the current selection.
    * Implement `navigator(_:canPerformAction:for:)` to validate each editing action for the current selection. For example, to make sure the selected text is not too large for a definition look up.
    * Implement `navigator(_:shouldShowMenuForSelection:)` to override the default edit menu (`UIMenuController`) with a custom selection pop-up.
* (*alpha*) Support for the [Decorator API](https://github.com/readium/architecture/pull/160) to draw user interface elements over a publication's content.
    * This can be used to render highlights over a text selection, for example.
    * For now, only the EPUB navigator implements `DecorableNavigator`. You can implement custom decoration styles with `HTMLDecorationTemplate`.
* (*alpha*) A new navigator for audiobooks.
  * The navigator is chromeless, so you will need to provide your own user interface.

### Deprecated

#### Navigator

* Removed `navigator(_:userContentController:didReceive:)` which is actually not needed since you can provide your own `WKScriptMessageHandler` to `WKUserContentController`.

### Changed

#### Streamer

* The default EPUB positions service now uses the archive entry length when available. [This is similar to how Adobe RMSDK generates page numbers](https://github.com/readium/architecture/issues/123).
    * To use the former strategy, create the `Streamer` with: `Streamer(parsers: [EPUBParser(reflowablePositionsStrategy: .originalLength(pageLength: 1024))])`

### Fixed

#### Streamer

* [#208](https://github.com/readium/r2-streamer-swift/issues/208) Crash when reading obfuscated EPUB resources with an empty publication identifier.

#### Navigator

* Fixed receiving `EPUBNavigatorDelegate.navigator(_:setupUserScripts:)` for the first web view.
* [r2-testapp-swift#343](https://github.com/readium/r2-testapp-swift/issues/343) Fixed hiding "Share" editing action (contributed by [@rocxteady](https://github.com/readium/r2-navigator-swift/pull/149)).


## 2.0.1

### Fixed

#### Shared

* [#139](https://github.com/readium/r2-shared-swift/pull/139) Compile error with Xcode 12.4


## 2.0.0

### Deprecated

* All APIs deprecated in previous versions are now unavailable.

#### Shared

* `DownloadSession` is deprecated and will be removed in the next major version. Please migrate to your own download solution.


## 2.0.0-beta.2

### Added

#### Shared

* `Resource` has a new API to perform progressive asynchronous reads. This is useful when streaming a resource.
* `HTTPFetcher` is a new publication fetcher able to serve remote resources through HTTP.
    * The actual HTTP requests are performed with an instance of `HTTPClient`.
* `HTTPClient` is a new protocol exposing a high level API to perform HTTP requests.
    * It supports simple fetches but also progressive downloads.
    * `DefaultHTTPClient` is an implementation of `HTTPClient` using standard `URLSession` APIs. You can use its delegate to customize how requests are created and even recover from errors, e.g. to implement Authentication for OPDS.
    * You can provide your own implementation of `HTTPClient` to Readium APIs if you prefer to use a third-party networking library.
* `PublicationServiceContext` now holds a weak reference to the parent `Publication`. This can be used to access other services from a given `PublicationService` implementation.
* The default `LocatorService` implementation can be used to get a `Locator` from a global progression in the publication.
    * `publication.locate(progression: 0.5)`

#### Streamer

* `Streamer` takes a new optional `HTTPClient` dependency to handle HTTP requests.

#### Navigator

* New `EPUBNavigatorDelegate` APIs to inject custom JavaScript.
  * Override `navigator(_:setupUserScripts:)` to register additional user script to the `WKUserContentController` of each web view.
  * Override `navigator(_:userContentController:didReceive:)` to receive callbacks from your scripts.

### Changed

#### Shared

* The `Archive` API now supports resource ownership at the entry level.
    * The default ZIP implementation takes advantage of this by opening a new ZIP stream for each resource to be served. This improves performances and memory safety.

#### Streamer

* The HTTP server now requests that publication resources are not cached by browsers.
  * Caching poses a security risk for protected publications.

#### LCP

* We removed the dependency to the private `R2LCPClient.framework`, which means:
    * Now `r2-lcp-swift` works as a Carthage dependency, no need to use a submodule anymore.
    * You do not need to modify `r2-lcp-swift`'s `Cartfile` anymore to add the private `liblcp` dependency.
    * However, you must provide a facade to `LCPService` (see [README](README.md) for an example implementation).
* The Renew Loan API got revamped to better support renewal through a web page.
    * You will need to implement `LCPRenewDelegate` to coordinate the UX interaction.
    * Readium ships with a default implementation `LCPDefaultRenewDelegate` to handle web page renewal with `SFSafariViewController`.

### Fixed

#### Shared

* Improved performances when reading consecutive ranges of a deflated ZIP entry.
* HREF normalization when a resource path contains special characters.

#### Navigator

* Optimized performances of preloaded EPUB resources.

#### LCP

* Fixed really slow opening of large PDF documents.


## 2.0.0-beta.1

### Added

#### Shared

* `PublicationAsset` is a new protocol which can be used to open a publication from various medium, such as a file, a remote URL or a custom source.
  * `File` was replaced by `FileAsset`, which implements `PublicationAsset`.

### Changed

#### Shared

* `Format` got merged into `MediaType`, to simplify the media type APIs.
  * You can use `MediaType.of()` to sniff the type of a file or bytes.
  * `MediaType` has now optional `name` and `fileExtension` properties.
  * Some publication formats can be represented by several media type aliases. Using `mediaType.canonicalized` will give you the canonical media type to use, for example when persisting the file type in a database. All Readium APIs are already returning canonical media types, so it only matters if you create a `MediaType` yourself from its string representation.
* `ContentLayout` is deprecated, use `publication.metadata.effectiveReadingProgression` to determine the reading progression of a publication instead.

#### Streamer

* `Streamer` is now expecting a `PublicationAsset` instead of a `File`. You can create custom implementations of
`PublicationAsset` to open a publication from different medium, such as a file, a remote URL, in-memory bytes, etc.
  * `FileAsset` can be used to replace `File` and provides the same behavior.

### Fixed

#### Navigator

* EPUBs declaring multiple languages were laid out from right to left if the first language had an RTL reading
progression. Now if no reading progression is set, the `effectiveReadingProgression` will be LTR.


## 2.0.0-alpha.2

### Added

#### Shared

* The [Publication Services API](https://readium.org/architecture/proposals/004-publication-helpers-services) allows to extend a `Publication` with custom implementations of known services. This version ships with a few predefined services:
  * `PositionsService` provides a list of discrete locations in the publication, no matter what the original format is.
  * `CoverService` provides an easy access to a bitmap version of the publication cover.
* The [Composite Fetcher API](https://readium.org/architecture/proposals/002-composite-fetcher-api) can be used to extend the way publication resources are accessed.
* Support for exploded directories for any archive-based publication format.
* [Content Protection](https://readium.org/architecture/proposals/006-content-protection) handles DRM and other format-specific protections in a more systematic way.
  * LCP now ships an `LCPContentProtection` implementation to be plugged into the `Streamer`.
  * You can add custom `ContentProtection` implementations to support other DRMs by providing an instance to the `Streamer`.
* A new `LinkRelation` type to represent link relations, instead of using raw strings.
  * This will improve code safety through type checking and enable code completion.
  * Since `LinkRelation` conforms to `ExpressibleByStringLiteral`, you can continue using raw strings in the API. However, migrating your code is recommended, e.g. `links.first(withRel: .cover)`.
  * Known link relations (including from OPDS specifications) are available under the `LinkRelation` namespace. You can easily add custom relations to the namespace by declaring `static` properties in a `LinkRelation` extension.

#### Streamer

* [Streamer API](https://readium.org/architecture/proposals/005-streamer-api) offers a simple interface to parse a publication and replace standalone parsers.
* A generic `ImageParser` for bitmap-based archives (CBZ or exploded directories) and single image files.
* A generic `AudioParser` for audio-based archives (Zipped Audio Book or exploded directories) and single audio files.

#### Navigator

* Support for the new `Publication` model using the [Content Protection](https://readium.org/architecture/proposals/006-content-protection) for DRM rights and the [Fetcher](https://readium.org/architecture/proposals/002-composite-fetcher-api) for resource access.
  * This replaces the `Container` and `DRMLicense` objects which were needed by the navigator before.

#### LCP

* LCP implementation of the [Content Protection API](https://readium.org/architecture/proposals/006-content-protection) to work with the new [Streamer API](https://readium.org/architecture/proposals/005-streamer-api).
  * It is highly recommended that you upgrade to the new `Streamer` API to open publications, which will simplify DRM unlocking.
* Two default implementations of `LCPAuthenticating`:
  * `LCPDialogAuthentication` to prompt the user for its passphrase with the official LCP dialog.
  * `LCPPassphraseAuthentication` to provide directly a passphrase, pulled for example from a database or a web service.
* `LCPService.acquirePublication()` is a new API to acquire a publication from a standalone license. Compared to the former `importPublication()`:
  * It doesn't require the passphrase, to allow bulk imports.
  * It can be cancelled by calling `cancel()` on the returned `LCPAcquisition` object.
* `LCPService.isLCPProtected()` provides a way to check if a file is protected with LCP.

### Changed

#### Shared

* [The `Publication` and `Container` types were merged together](https://readium.org/architecture/proposals/003-publication-encapsulation) to offer a single interface to a publication's resources.
  * Use `publication.get()` to read the content of a resource, such as the cover. It will automatically be decrypted if a `ContentProtection` was attached to the `Publication`.

#### Streamer

* `Container` and `ContentFilters` were replaced by a shared implementation of a [`Fetcher`](https://readium.org/architecture/proposals/002-composite-fetcher-api).
* `PDFFileParser` was replaced in favor of a shared `PDFDocument` protocol. This version ships with two implementations using PDFKit and CoreGraphics.

#### LCP

* `LCPAuthenticating` is now provided with more information and you will need to update your implementation.

### Fixed

#### Streamer

* Deobfuscating ranges of EPUB resources.

#### Navigator

* Layout of right-to–left EPUB.
* [Various EPUB navigation issues](https://github.com/readium/r2-navigator-swift/pull/142):
  * Prevent breaking initial location when calling `updateUserSettings` too soon.
  * Fix weird scrolling behavior when double tapping on the edges to turn pages.
  * Don't send intermediate incorrect locators when loading a pending locator.
* Optimize positions calculation for LCP protected PDF.

#### LCP

* [Decrypting resources in some edge cases](https://github.com/readium/r2-lcp-swift/pull/94).


## 2.0.0-alpha.1

### Added

#### Shared

* The new [Format API](https://readium.org/architecture/proposals/001-format-api.md) simplifies the detection of file formats, including known publication formats such as EPUB and PDF.
  * [A format can be "sniffed"](https://readium.org/architecture/proposals/001-format-api.md#sniffing-the-format-of-raw-bytes) from files, raw bytes or even HTTP responses.
  * Reading apps are welcome to [extend the API with custom formats](https://readium.org/architecture/proposals/001-format-api.md#supporting-a-custom-format).
  * Using `Link.mediaType?.matches()` is now recommended [to safely check the type of a resource](https://readium.org/architecture/proposals/001-format-api.md#mediatype-class).
  * [More details about the Swift implementation can be found in the pull request.](https://github.com/readium/r2-shared-swift/pull/88)
* In `Publication` shared models:
  * [Presentation Hints](https://readium.org/webpub-manifest/extensions/presentation.html) and [HTML Locations](https://readium.org/architecture/models/locators/extensions/html.md) extensions.
  * Support for OPDS holds, copies and availability in `Link`, for library-specific features.
* (*alpha*) Audiobook toolkit:
  * [`AudioSession`](https://github.com/readium/r2-shared-swift/pull/91) simplifies the setup of an `AVAudioSession` and handling its interruptions.
  * [`NowPlayingInfo`](https://github.com/readium/r2-shared-swift/pull/91) helps manage the ["Now Playing"](https://developer.apple.com/documentation/mediaplayer/becoming_a_now_playable_app) information displayed on the lock screen.

#### Streamer

* `ReadiumWebPubParser` to parse all Readium Web Publication profiles, including [Audiobooks](https://readium.org/webpub-manifest/extensions/audiobook.html) and [LCP for PDF](https://readium.org/lcp-specs/notes/lcp-for-pdf.html). It parses both manifests and packages.

#### Navigator

* Support for pop-up footnotes (contributed by [@tooolbox](https://github.com/readium/r2-navigator-swift/pull/118)).
  * **This is an opt-in feature**. Reading apps can customize how footnotes are presented to the user by implementing `NavigatorDelegate.navigator(_:shouldNavigateToNoteAt:content:referrer:)`. [An example presenting footnotes in pop-ups is demonstrated in the Test App](https://github.com/readium/r2-testapp-swift/pull/328).
  * Footnotes' content is extracted with [scinfu/SwiftSoup](https://github.com/scinfu/SwiftSoup), which you may need to add to your app if you're not using Carthage or CocoaPods.
* In EPUB's user settings:
  * Support for hyphenation (contributed by [@ehapmgs](https://github.com/readium/r2-navigator-swift/pull/76)).
  * Publishers' default styles are now used by default.
  * Default line height is increased to improve readability.
* JavaScript errors are logged in Xcode's console for easier debugging.

#### LCP

* Support for [PDF](https://readium.org/lcp-specs/notes/lcp-for-pdf.html) and [Readium Audiobooks](https://readium.org/lcp-specs/notes/lcp-for-audiobooks.html) protected with LCP.

### Changed

#### Shared

* All the `Publication` shared models are now immutable, to improve code safety. This should not impact reading apps unless you created `Publication` or other models yourself.
* The `DocumentTypes` API was extended and [offers an easy way to check if your app supports a given file](https://github.com/readium/r2-testapp-swift/pull/325/files#diff-afef0c51328e306d131d64cdf716a1d1R21-R24).
* Dependencies to format-related third-party libraries such as ZIP, XML and PDF are being consolidated into `r2-shared-swift`. Therefore, `r2-shared-swift` now depends on Fuzi and ZIPFoundation. This change will improve maintainability by isolating third-party code and allow (work in progress) to substitute the default libraries with custom ones.

#### Navigator

* [Upgraded to Readium CSS 1.0.0-beta.1.](https://github.com/readium/r2-navigator-swift/pull/125)
  * Two new fonts are available: AccessibleDfa and IA Writer Duospace.
  * The file structure now follows strictly the one from [ReadiumCSS's `dist/`](https://github.com/readium/readium-css/tree/master/css/dist), for easy upgrades and custom builds replacement.
      
#### LCP

* `LCPAuthenticating` can now return hashed passphrases in addition to clear ones. [This can be used by reading apps](https://github.com/readium/r2-lcp-swift/pull/75) fetching hashed passphrases from a web service or [Authentication for OPDS](https://readium.org/lcp-specs/notes/lcp-key-retrieval.html), for example.
* Provided `LCPAuthenticating` instances are now retained by the LCP service. Therefore, you can provide one without keeping a reference around in your own code.

### Fixed

#### Streamer

* Significant performance improvement when opening PDF documents protected with LCP.
* [Prevent the embedded HTTP server from stopping when the device is locked](https://github.com/readium/r2-streamer-swift/pull/163), to allow background playback of audiobooks.

#### Navigator

* Jumping to a bookmark (`Locator`) located in a resource that is not already pre-loaded used to fail for some publications.
* Touching interactive elements in fixed-layout EPUBs, when two-page spreads are enabled.


[unreleased]: https://github.com/readium/swift-toolkit/compare/main...HEAD
[2.3.0]: https://github.com/readium/swift-toolkit/compare/2.2.0...2.3.0
