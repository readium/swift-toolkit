# Changelog

All notable changes to this project will be documented in this file.

**Warning:** Features marked as *experimental* may change or be removed in a future release without notice. Use with caution.

## [Unreleased]

## [2.0.0-alpha.2]

### Added

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

### Changed

* [The `Publication` and `Container` types were merged together](https://readium.org/architecture/proposals/003-publication-encapsulation) to offer a single interface to a publication's resources.
  * Use `publication.get()` to read the content of a resource, such as the cover. It will automatically be decrypted if a `ContentProtection` was attached to the `Publication`.


## [2.0.0-alpha.1]

### Added

* The new [Format API](https://readium.org/architecture/proposals/001-format-api.md) simplifies the detection of file formats, including known publication formats such as EPUB and PDF.
  * [A format can be "sniffed"](https://readium.org/architecture/proposals/001-format-api.md#sniffing-the-format-of-raw-bytes) from files, raw bytes or even HTTP responses.
  * Reading apps are welcome to [extend the API with custom formats](https://readium.org/architecture/proposals/001-format-api.md#supporting-a-custom-format).
  * Using `Link.mediaType?.matches()` is now recommended [to safely check the type of a resource](https://readium.org/architecture/proposals/001-format-api.md#mediatype-class).
  * [More details about the Swift implementation can be found in the pull request.](https://github.com/readium/r2-shared-swift/pull/88)
* In `Publication` shared models:
  * [Presentation Hints](https://readium.org/webpub-manifest/extensions/presentation.html) and [HTML Locations](https://readium.org/architecture/models/locators/extensions/html.md) extensions.
  * Support for OPDS holds, copies and availability in `Link`, for library-specific features.
* (*Experimental*) Audiobook toolkit:
  * [`AudioSession`](https://github.com/readium/r2-shared-swift/pull/91) simplifies the setup of an `AVAudioSession` and handling its interruptions.
  * [`NowPlayingInfo`](https://github.com/readium/r2-shared-swift/pull/91) helps manage the ["Now Playing"](https://developer.apple.com/documentation/mediaplayer/becoming_a_now_playable_app) information displayed on the lock screen.

### Changed

* All the `Publication` shared models are now immutable, to improve code safety. This should not impact reading apps unless you created `Publication` or other models yourself.
* The `DocumentTypes` API was extended and [offers an easy way to check if your app supports a given file](https://github.com/readium/r2-testapp-swift/pull/325/files#diff-afef0c51328e306d131d64cdf716a1d1R21-R24).
* Dependencies to format-related third-party libraries such as ZIP, XML and PDF are being consolidated into `r2-shared-swift`. Therefore, `r2-shared-swift` now depends on Fuzi and ZIPFoundation. This change will improve maintainability by isolating third-party code and allow (work in progress) to substitute the default libraries with custom ones.

[unreleased]: https://github.com/readium/r2-shared-swift/compare/master...HEAD
[2.0.0-alpha.1]: https://github.com/readium/r2-shared-swift/compare/1.4.3...2.0.0-alpha.1
[2.0.0-alpha.2]: https://github.com/readium/r2-shared-swift/compare/2.0.0-alpha.1...2.0.0-alpha.2
