# Changelog

All notable changes to this project will be documented in this file. Take a look at [the migration guide](docs/Migration%20Guide.md) to upgrade between two major versions.

<!-- ## [Unreleased] -->

## [3.4.0]

### Added

#### Navigator

* You can now access the `viewport` property of an `EPUBNavigatorViewController` to obtain information about the visible portion of the publication, including the visible positions and reading order indices.

### Deprecated

#### Shared

* The Presentation Hints properties are deprecated from the Readium Web Publication Manifest models. [See the official documentation](https://readium.org/webpub-manifest/profiles/epub.html#appendix-b---deprecated-properties).

### Changed

#### Streamer

* EPUB series added with Calibre now take precedence over the native EPUB ones in the `belongsToSeries` RWPM property.

### Fixed

#### Streamer

* [#639](https://github.com/readium/swift-toolkit/issues/639) Optimized the opening of really large LCP protected publications.

#### Navigator

* [#70](https://github.com/readium/swift-toolkit/issues/70) Fixed restoring the reading progression with RTL EPUB.
* EPUB vertical text in scrolling mode:
    * [#556](https://github.com/readium/swift-toolkit/issues/556) Fixed reporting and restoring the reading progression.
    * Added support for decorations (highlights).
* [#635](https://github.com/readium/swift-toolkit/issues/635) Fixed overlapping FXL pages in landscape orientation.


## [3.3.0]

### Added

#### Shared

* Implementation of the [W3C Accessibility Metadata Display Guide](https://w3c.github.io/publ-a11y/a11y-meta-display-guide/2.0/guidelines/) specification to facilitate displaying accessibility metadata to users. [See the dedicated user guide](docs/Guides/Accessibility.md).
* Support for starting from a progression in the HTML content iterator.
* New link `rels` in the `readingOrder` and EPUB `landmarks` to mark:
    * `cover`: the title page
    * `contents`: the table of contents
    * `start`: the first actual chapter

#### Navigator

* A new `InputObserving` API has been added to enable more flexible gesture recognition and support for mouse pointers. [See the dedicated user guide](docs/Guides/Navigator/Input.md).

#### Streamer

* The EPUB 2 `<guide>` element is now parsed into the RWPM `landmarks` subcollection when no EPUB 3 `landmarks` navigation document is declared.

#### LCP

* A brand new LCP authentication dialog for SwiftUI applications. [See the accompanying user guide](docs/Guides/Readium%20LCP.md).

### Fixed

#### Navigator

* Fixed several issues with the EPUB navigator cursor and pointer events.
    * Fixed the cursor shape on iPadOS when using a physical trackpad or mouse.
    * Fixed multiple tap events broadcasted while running on macOS.
* [#449](https://github.com/readium/swift-toolkit/issues/449) Fixed misaligned EPUB navigator when it does not span the full screen width.


## [3.2.0]

### Added

#### Shared

* Support for [W3C's Text & data mining Reservation Protocol](https://www.w3.org/community/reports/tdmrep/CG-FINAL-tdmrep-20240510/) in our metadata models.
* Support for [accessibility exemption metadata](https://readium.org/webpub-manifest/contexts/default/#exemption), which allows content creators to identify publications that do not meet conformance requirements but fall under exemptions in a given juridiction.
* Support for [EPUB Accessibility 1.1](https://www.w3.org/TR/epub-a11y-11/) conformance profiles.

#### LCP

* Support for streaming an LCP-protected publication from its License Document (LCPL). [Take a look at the LCP guide for more information](docs/Guides/Readium%20LCP.md#streaming-an-lcp-protected-package).

### Changed

#### Shared

* The `absoluteURL` and `relativeURL` extensions on `URLConvertible` were removed as they conflict with the native `URL.absoluteURL`.
    * If you were using them, you can for example still use `anyURL.absoluteURL` instead.
* [go-toolkit#92](https://github.com/readium/go-toolkit/issues/92) The accessibility feature `printPageNumbers` is deprecated in favor of `pageNavigation`.

#### Streamer

* A `self` link is not required anymore when parsing a RWPM.

### Fixed

#### Navigator

* Fixed going to a link containing a fragment in the PDF navigator, for example from the table of contents.


## [3.1.0]

### Added

#### Shared

* Support for streaming ZIP packages over HTTP. This lets you open a remote EPUB, audiobook, or any other ZIP-based publication without needing to download it first.

### Deprecated

* The `close()` and `Closeable` APIs are now deprecated. Resources are automatically released upon `deinit`, which aligns better with Swift.

### Fixed

#### LCP

* Fixed a regression that caused some LCP passphrases to no longer match the protected publication.

#### Navigator

* Fixed race condition when calling `submitPreferences()` before the EPUB navigator is fully initialized.


## [3.0.0-beta.2]

* The Readium Swift toolkit now requires a minimum of iOS 13.4.
* All the libraries are now available on a dedicated [Readium CocoaPods Specs repository](https://github.com/readium/podspecs). Take a look at [the migration guide](docs/Migration%20Guide.md) to migrate.

### Added

#### Navigator

* The `EPUBNavigatorViewController.Configuration.disablePageTurnsWhileScrolling` property disables horizontal swipes for navigating to previous or next resources when scroll mode is enabled. When set to `true`, you must implement your own mechanism to move to the next resource (contributed by [@alecdhansen](https://github.com/readium/swift-toolkit/pull/531)).

### Changed

#### Shared

* The default `ZIPArchiveOpener` is now using ZIPFoundation instead of Minizip, with improved performances when reading ranges of `stored` ZIP entries.
* Improvements in the HTTP client:
    * The `consume` closure of `HTTPClient.stream()` can now return an error to abort the HTTP request.
    * `HTTPError` has been refactored for improved type safety and a clearer separation of connection errors versus HTTP errors.
    * `DefaultHTTPClient` no longer automatically restarts a failed `HEAD` request as a `GET` to retrieve the response body. If you relied on this behavior, you can implement it using a custom `DefaultHTTPClientDelegate.httpClient(_:recoverRequest:fromError:)`.

### Fixed

#### Shared

* Fixed a crash using `HTTPClient.download()` when the device storage is full.

#### Navigator

* [#509](https://github.com/readium/swift-toolkit/issues/509) Removed the "Copy Link with Highlight" and "Writing Tools" EPUB editing actions on newer devices.

#### OPDS

* Fixed a data race in the OPDS 1 parser.


## [3.0.0-beta.1]

### Added

#### Shared

* `TableOfContentsService` can now be used to customize the computation of `publication.tableOfContents()`.

#### LCP

* The table of contents of an LCP-protected PDF is now extracted directly from the PDF if the `tableOfContents` property in `manifest.json` is empty.

### Fixed

* [#489](https://github.com/readium/swift-toolkit/issues/489) Fix crash related to Fuzi when compiling with Xcode 16 in release mode.

#### Navigator

* [#502](https://github.com/readium/swift-toolkit/issues/502) Fixed accessibility editing actions on iOS 18.


## [3.0.0-alpha.3]

### Fixed

#### Navigator

* [#459](https://github.com/readium/swift-toolkit/issues/459) Fixed the stack overflow issue that occurred when running the text-to-speech on an EPUB file with many empty resources.
* [#490](https://github.com/readium/swift-toolkit/issues/490) Fixed issue loading fixed-layout EPUBs.


## [3.0.0-alpha.2]

### Added

#### Streamer

* Support for standalone audio files and their metadata (contributed by [@domkm](https://github.com/readium/swift-toolkit/pull/414)).

### Changed

* The Readium Swift toolkit now requires a minimum of iOS 13.
* Plenty of completion-based APIs were changed to use `async` functions instead.

#### Shared

* A new `Format` type was introduced to augment `MediaType` with more precise information about the format specifications of an `Asset`.
* `Fetcher` was replaced with a simpler `Container` type.
* `PublicationAsset` was replaced by `Asset`, which contains a `Format` and access to the underlying `Container` or `Resource`.
* The `ResourceError` hierarchy was revamped and simplified (see `ReadError`). Now it is your responsibility to provide a localized user message for each error case.
* The `Link` property key for archive-based publication assets (e.g. an EPUB/ZIP) is now `https://readium.org/webpub-manifest/properties#archive` instead of `archive`.
* The API of `HTTPServer` slightly changed to be more future-proof.

#### Streamer

* The `Streamer` object was deprecated in favor of smaller segregated APIs: `AssetRetriever` and `PublicationOpener`. 

#### Navigator

* EPUB: The `scroll` preference is now forced to `true` when rendering vertical text (e.g. CJK vertical). [See this discussion for the rationale](https://github.com/readium/swift-toolkit/discussions/370).

#### LCP

* The Readium LCP persistence layer was extracted to allow applications to provide their own implementations. Take a look at [the migration guide](docs/Migration%20Guide.md) for guidance.

### Fixed

#### Navigator

* Optimized scrolling to an EPUB text-based locator if it contains a CSS selector.
* The first resource of a fixed-layout EPUB is now displayed on its own when spreads are enabled and the author has not set a `page-spread-*` property. This is the default behavior in major reading apps like Apple Books.
* [#471](https://github.com/readium/swift-toolkit/issues/471) EPUB: Fixed reporting the current location when submitting new preferences.


## [3.0.0-alpha.1]

### Changed

* The `R2Shared`, `R2Streamer` and `R2Navigator` packages are now called `ReadiumShared`, `ReadiumStreamer` and `ReadiumNavigator`.
* Many APIs now expect one of the new URL types (`RelativeURL`, `AbsoluteURL`, `HTTPURL` and `FileURL`). This is helpful because:
    * It validates at compile time that we provide a URL that is supported.
    * The API's capabilities are better documented, e.g. a download API could look like this : `download(url: HTTPURL) -> FileURL`. 

#### Shared

* `Link` and `Locator`'s `href` are normalized as valid URLs to improve interoperability with the Readium Web toolkits.
   * **You MUST migrate your database if you were persisting HREFs and Locators**. Take a look at [the migration guide](docs/Migration%20Guide.md) for guidance.
* Links are not resolved to the `self` URL of a manifest anymore. However, you can still normalize the HREFs yourselves by calling `Manifest.normalizeHREFsToSelf()`.
* `Publication.localizedTitle` is now optional, as we cannot guarantee a publication will always have a title.


## [2.7.4]

### Fixed

* [#489](https://github.com/readium/swift-toolkit/issues/489) Fix crash related to Fuzi when compiling with Xcode 16 in release mode.

#### Navigator

* [#502](https://github.com/readium/swift-toolkit/issues/502) Fixed accessibility editing actions on iOS 18.


## [2.7.3]

### Fixed

* [#483](https://github.com/readium/swift-toolkit/issues/483) Fixed build on Xcode 16.


## [2.7.2]

### Fixed

#### Shared

* [#444](https://github.com/readium/swift-toolkit/issues/444) Fixed resolving titles of search results when the table of contents items contain fragment identifiers.

#### Navigator

* [#428](https://github.com/readium/swift-toolkit/issues/428) Fixed crash with the `share` editing action on iOS 17.
* [#428](https://github.com/readium/swift-toolkit/issues/428) Fixed showing look up and translate editing actions on iOS 17.


## [2.7.1]

### Added

* [#417](https://github.com/readium/swift-toolkit/issues/417) Support for the new 2.x LCP Profiles.


## [2.7.0]

### Added

#### Shared

* You can now use `DefaultHTTPClientDelegate.httpClient(_:request:didReceive:completion:)` to handle authentication challenges (e.g. Basic) with `DefaultHTTPClient`.

#### Navigator

* The `AudioNavigator` API has been promoted to stable and ships with a new Preferences API.
* The new `NavigatorDelegate.didFailToLoadResourceAt(_:didFailToLoadResourceAt:withError:)` delegate API notifies when an error occurs while loading a publication resource (contributed by [@ettore](https://github.com/readium/swift-toolkit/pull/400)).

### Fixed

* [#390](https://github.com/readium/swift-toolkit/issues/390) Fixed logger not logging above the minimum severity level (contributed by [@ettore](https://github.com/readium/swift-toolkit/pull/391)).

#### Navigator

* From iOS 13 to 15, PDF text selection is disabled on protected publications disabling the **Copy** editing action.
* The **Share** editing action is disabled for any protected publication.
* Fixed starting the TTS from the current EPUB position.
* [#396](https://github.com/readium/swift-toolkit/issues/396) Ensure we stop the activity indicator when an EPUB resource fails to load correctly (contributed by [@ettore](https://github.com/readium/swift-toolkit/pull/397)).

#### Streamer

* [#399](https://github.com/readium/swift-toolkit/discussions/399) Zipped Audio Books and standalone audio files are now recognized.


## [2.6.1]

### Added

#### Navigator

* You can now customize the playback refresh rate of `_AudiobookNavigator` in its configuration.
* The EPUB navigator automatically moves to the next resource when VoiceOver reaches the end of the current one.

### Changed

#### Navigator

* You should not subclass `PDFNavigatorViewController` anymore. If you need to override `setupPDFView`, you can do so by implementing the `PDFNavigatorDelegate` protocol.

### Fixed

#### Shared

* Zipped Audio Book archives are now detected even if they contain bitmap entries.

#### Navigator

* [#344](https://github.com/readium/swift-toolkit/issues/344) EPUB: Fixed lost position when rotating quickly the screen several times.
* [#350](https://github.com/readium/swift-toolkit/discussions/350) Restore the ability to subclass the `PDFNavigatorViewController`.
* Fixed activating the scroll mode when VoiceOver is enabled in the EPUB navigator.


## [2.6.0]

* Support for Xcode 15.

### Added

#### Navigator

* The `PublicationSpeechSynthesizer` (TTS) now supports background playback by default.
    * You will need to enable the **Audio Background Mode** in your app's build info.
* Support for non-linear EPUB resources with an opt-in in reading apps (contributed by @chrfalch in [#332](https://github.com/readium/swift-toolkit/pull/332) and [#331](https://github.com/readium/swift-toolkit/pull/331)).
    1. Override loading non-linear resources with `VisualNavigatorDelegate.navigator(_:shouldNavigateToLink:)`.
    2. Present a new `EPUBNavigatorViewController` by providing a custom `readingOrder` with only this resource to the constructor.

### Fixed

#### Navigator

* Improved performance when adding hundreds of HTML decorations at once.
* Fixed broadcasting the `PublicationSpeechSynthesizer` with AirPlay when the screen is locked.

### Changed

#### Navigator

* `AudioSession` and `NowPlayingInfo` are now stable!
* You need to provide the configuration of the Audio Session to the constructor of `PublicationSpeechSynthesizer`, instead of `AVTTSEngine`.


## [2.5.1]

* The Readium toolkit now requires iOS 11.0+.

### Added

#### Navigator

* The `auto` spread setting is now available for fixed-layout EPUBs. It will display two pages in landscape and a single one in portrait.

#### Streamer

* The EPUB content iterator now returns `audio` and `video` elements and fill in the `progression` and `totalProgression` locator properties.

### Changed

#### Navigator

* `EPUBNavigatorViewController.firstVisibleElementLocator()` now returns the first *block* element that is visible on the screen, even if it starts on previous pages.
    * This is used to make sure the user will not miss any context when restoring a TTS session in the middle of a resource.

### Fixed

#### Navigator

* Fixed the PDF `auto` spread setting and scaling pages when rotating the screen.
* Fixed navigating to the first chapter of an audiobook with a single resource (contributed by [@grighakobian](https://github.com/readium/swift-toolkit/pull/292)).
* Prevent auto-playing videos in EPUB publications.
* Fixed various memory leaks and data races.
* The `WKWebView` is now inspectable again with Safari starting from iOS 16.4.
* Fixed crash in the `PublicationSpeechSynthesizer` when closing the navigator without stopping it first.
* Fixed pausing the `PublicationSpeechSynthesizer` right before starting the utterance.
* Fixed the audio session kept opened while the app is in the background and paused.
* Fixed the **Attribute dir redefined** error when the EPUB resource already has a `dir` attribute.
* [#309](https://github.com/readium/swift-toolkit/issues/309) Fixed restoring the EPUB location when the application was killed in the background (contributed by [@triin-ko](https://github.com/readium/swift-toolkit/pull/311)).

#### Streamer

* Fix issue with the TTS starting from the beginning of the chapter instead of the current position.


## [2.5.0]

### Added

#### Streamer

* Positions computation, TTS and search is now enabled for Readium Web Publications conforming to the [EPUB profile](https://readium.org/webpub-manifest/profiles/epub.html).

#### Navigator

* New `VisualNavigatorDelegate` APIs to handle keyboard events (contributed by [@lukeslu](https://github.com/readium/swift-toolkit/pull/267)).
    * This can be used to turn pages with the arrow keys, for example.
* [Support for custom fonts with the EPUB navigator](docs/Guides/EPUB%20Fonts.md).
* A brand new user preferences API for configuring the EPUB and PDF Navigators. This new API is easier and safer to use. To learn how to integrate it in your app, [please refer to the user guide](docs/Guides/Navigator%20Preferences.md) and [migration guide](docs/Migration%20Guide.md).
    * New EPUB user preferences:
        * `fontWeight` - Base text font weight.
        * `textNormalization` - Normalize font style, weight and variants, which improves accessibility.
        * `imageFilter` - Filter applied to images in dark theme (darken, invert colors)
        * `language` - Language of the publication content.
        * `readingProgression` - Direction of the reading progression across resources, e.g. RTL.
        * `typeScale` - Scale applied to all element font sizes.
        * `paragraphIndent` - Text indentation for paragraphs.
        * `paragraphSpacing` - Vertical margins for paragraphs.
        * `hyphens` - Enable hyphenation.
        * `ligatures` - Enable ligatures in Arabic.
    * New PDF user preferences:
        * `backgroundColor` - Background color behind the document pages.
        * `offsetFirstPage` - Indicate if the first page should be displayed in its own spread.
        * `pageSpacing` - Spacing between pages in points.
        * `readingProgression` - Direction of the reading progression across resources, e.g. RTL.
        * `scrollAxis` - Scrolling direction when `scroll` is enabled.
        * `scroll` - Indicate if pages should be handled using scrolling instead of pagination.
        * `spread` - Enable dual-page mode.
        * `visibleScrollbar` - Indicate whether the scrollbar should be visible while scrolling.
* The new `DirectionalNavigationAdapter` component helps you to turn pages with the arrows and space keyboard keys or taps on the edge of the screen.

### Deprecated

#### Streamer

* `PublicationServer` is deprecated. See the [the migration guide](docs/Migration%20Guide.md#2.5.0) to migrate the HTTP server.

#### Navigator

* The EPUB `UserSettings` component is deprecated and replaced by the new Preferences API. [Take a look at the user guide](docs/Guides/Navigator%20Preferences.md) and [migration guide](docs/Migration%20Guide.md).

### Changed

#### Navigator

* The `define` editing action replaces `lookup` on iOS 16+. When enabled, it will show both the "Look Up" and "Search Web" menu items.
* Prevent navigation in the EPUB while it is being loaded.

### Fixed

#### Navigator

* Fixed a race condition issue with the `AVTTSEngine`, when pausing utterances.
* Fixed crash with `PublicationSpeechSynthesizer`, when the currently played word cannot be resolved.
* Fixed EPUB tap event sent twice when using a mouse (e.g. on Apple Silicon or with a mouse on an iPad).


## [2.4.0]

### Added

#### Shared

* Support for the accessibility metadata in RWPM per [Schema.org Accessibility Properties for Discoverability Vocabulary](https://www.w3.org/2021/a11y-discov-vocab/latest/).
* [Extract the raw content (text, images, etc.) of a publication](docs/Guides/Content.md).

#### Navigator

* [A brand new text-to-speech implementation](docs/Guides/TTS.md).

#### Streamer

* Parse EPUB accessibility metadata ([see documentation](https://readium.org/architecture/streamer/parser/a11y-metadata-parsing)).

### Deprecated

#### Shared

* `Locator(link: Link)` is deprecated as it may create an incorrect `Locator` if the link `type` is missing.
    * Use `publication.locate(Link)` instead.

### Fixed

* [#244](https://github.com/readium/swift-toolkit/issues/244) Fixed build with Xcode 14 and Carthage/CocoaPods.

#### Navigator

* Fixed memory leaks in the EPUB and PDF navigators.
* [#61](https://github.com/readium/swift-toolkit/issues/61) Fixed serving EPUB resources when the HREF contains an anchor or query parameters.
* Performance issue with EPUB fixed-layout when spreads are enabled.
* Disable scrolling in EPUB fixed-layout resources, in case the viewport is incorrectly set.
* Fix vertically bouncing EPUB resources in iOS 16.

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
[2.4.0]: https://github.com/readium/swift-toolkit/compare/2.3.0...2.4.0
[2.5.0]: https://github.com/readium/swift-toolkit/compare/2.4.0...2.5.0
[2.5.1]: https://github.com/readium/swift-toolkit/compare/2.5.0...2.5.1
[2.6.0]: https://github.com/readium/swift-toolkit/compare/2.5.1...2.6.0
[2.6.1]: https://github.com/readium/swift-toolkit/compare/2.6.0...2.6.1
[2.7.0]: https://github.com/readium/swift-toolkit/compare/2.6.1...2.7.0
[2.7.1]: https://github.com/readium/swift-toolkit/compare/2.7.0...2.7.1
[2.7.2]: https://github.com/readium/swift-toolkit/compare/2.7.1...2.7.2
[2.7.3]: https://github.com/readium/swift-toolkit/compare/2.7.2...2.7.3
[2.7.4]: https://github.com/readium/swift-toolkit/compare/2.7.3...2.7.4
[3.0.0-alpha.1]: https://github.com/readium/swift-toolkit/compare/2.7.1...3.0.0-alpha.1
[3.0.0-alpha.2]: https://github.com/readium/swift-toolkit/compare/3.0.0-alpha.1...3.0.0-alpha.2
[3.0.0-alpha.3]: https://github.com/readium/swift-toolkit/compare/3.0.0-alpha.2...3.0.0-alpha.3
[3.0.0-beta.1]: https://github.com/readium/swift-toolkit/compare/3.0.0-alpha.3...3.0.0-beta.1
[3.0.0-beta.2]: https://github.com/readium/swift-toolkit/compare/3.0.0-beta.1...3.0.0-beta.2
[3.1.0]: https://github.com/readium/swift-toolkit/compare/3.0.0...3.1.0
[3.2.0]: https://github.com/readium/swift-toolkit/compare/3.1.0...3.2.0
[3.3.0]: https://github.com/readium/swift-toolkit/compare/3.2.0...3.3.0
[3.4.0]: https://github.com/readium/swift-toolkit/compare/3.3.0...3.4.0
