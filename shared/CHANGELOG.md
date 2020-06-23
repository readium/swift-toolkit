# Changelog

All notable changes to this project will be documented in this file.

**Warning:** Features marked as *experimental* may change or be removed in a future release without notice. Use with caution.

## [Unreleased]

### Added

* The new [Format API](https://github.com/readium/architecture/blob/master/proposals/001-format-api.md) simplifies the detection of file formats, including known publication formats such as EPUB and PDF.
  * [A format can be "sniffed"](https://github.com/readium/architecture/blob/master/proposals/001-format-api.md#sniffing-the-format-of-raw-bytes) from files, raw bytes or even HTTP responses.
  * Reading apps are welcome to [extend the API with custom formats](https://github.com/readium/architecture/blob/master/proposals/001-format-api.md#supporting-a-custom-format).
  * Using `Link.mediaType?.matches()` is now recommended [to safely check the type of a resource](https://github.com/readium/architecture/blob/master/proposals/001-format-api.md#mediatype-class).
  * [More details about the Swift implementation can be found in the pull request.](https://github.com/readium/r2-shared-swift/pull/88)
* In `Publication` shared models:
  * [Presentation Hints](https://readium.org/webpub-manifest/extensions/presentation.html) and [HTML Locations](https://github.com/readium/architecture/blob/master/models/locators/extensions/html.md) extensions.
  * Support for OPDS holds, copies and availability in `Link`, for library-specific features.
* (*Experimental*) Audiobook toolkit:
  * [`AudioSession`](https://github.com/readium/r2-shared-swift/pull/91) simplifies the setup of an `AVAudioSession` and handling its interruptions.
  * [`NowPlayingInfo`](https://github.com/readium/r2-shared-swift/pull/91) helps manage the ["Now Playing"](https://developer.apple.com/documentation/mediaplayer/becoming_a_now_playable_app) information displayed on the lock screen.

### Changed

* All the `Publication` shared models are now immutable, to improve code safety. This should not impact reading apps unless you created `Publication` or other models yourself.
* The `DocumentTypes` API was extended and [offers an easy way to check if your app supports a given file](https://github.com/readium/r2-testapp-swift/pull/325/files#diff-afef0c51328e306d131d64cdf716a1d1R21-R24).
* Dependencies to format-related third-party libraries such as ZIP, XML and PDF are being consolidated into `r2-shared-swift`. Therefore, `r2-shared-swift` now depends on Fuzi and ZIPFoundation. This change will improve maintainability by isolating third-party code and allow (work in progress) to substitute the default libraries with custom ones.

[unreleased]: https://github.com/readium/r2-shared-swift/compare/master...HEAD
[x.x.x]: https://github.com/readium/r2-shared-swift/compare/1.4.3...x.x.x
