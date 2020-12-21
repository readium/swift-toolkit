# Changelog

All notable changes to this project will be documented in this file.

**Warning:** Features marked as *experimental* may change or be removed in a future release without notice. Use with caution.

## [Unreleased]

### Changed

* `Streamer` is now expecting a `PublicationAsset` instead of a `File`. You can create custom implementations of
`PublicationAsset` to open a publication from different medium, such as a file, a remote URL, in-memory bytes, etc.
  * `FileAsset` can be used to replace `File` and provides the same behavior.
  

## [2.0.0-alpha.2]

### Added

* [Streamer API](https://readium.org/architecture/proposals/005-streamer-api) offers a simple interface to parse a publication and replace standalone parsers.
* A generic `ImageParser` for bitmap-based archives (CBZ or exploded directories) and single image files.
* A generic `AudioParser` for audio-based archives (Zipped Audio Book or exploded directories) and single audio files.

### Changed

* `Container` and `ContentFilters` were replaced by a shared implementation of a [`Fetcher`](https://readium.org/architecture/proposals/002-composite-fetcher-api).
* `PDFFileParser` was replaced in favor of a shared `PDFDocument` protocol. This version ships with two implementations using PDFKit and CoreGraphics.

### Fixed

* Deobfuscating ranges of EPUB resources.


## [2.0.0-alpha.1]

### Added

* `ReadiumWebPubParser` to parse all Readium Web Publication profiles, including [Audiobooks](https://readium.org/webpub-manifest/extensions/audiobook.html) and [LCP for PDF](https://readium.org/lcp-specs/notes/lcp-for-pdf.html). It parses both manifests and packages.

### Fixed

* Significant performance improvement when opening PDF documents protected with LCP.
* [Prevent the embedded HTTP server from stopping when the device is locked](https://github.com/readium/r2-streamer-swift/pull/163), to allow background playback of audiobooks.

[unreleased]: https://github.com/readium/r2-streamer-swift/compare/master...HEAD
[2.0.0-alpha.1]: https://github.com/readium/r2-streamer-swift/compare/1.2.5...2.0.0-alpha.1
[2.0.0-alpha.2]: https://github.com/readium/r2-streamer-swift/compare/2.0.0-alpha.1...2.0.0-alpha.2
