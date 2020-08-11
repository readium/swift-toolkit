# Changelog

All notable changes to this project will be documented in this file.

**Warning:** Features marked as *experimental* may change or be removed in a future release without notice. Use with caution.

## [Unreleased]

## [2.0.0-alpha.1]

### Added

* `ReadiumWebPubParser` to parse all Readium Web Publication profiles, including [Audiobooks](https://readium.org/webpub-manifest/extensions/audiobook.html) and [LCP for PDF](https://readium.org/lcp-specs/notes/lcp-for-pdf.html). It parses both manifests and packages.

### Fixed

* Significant performance improvement when opening PDF documents protected with LCP.
* [Prevent the embedded HTTP server from stopping when the device is locked](https://github.com/readium/r2-streamer-swift/pull/163), to allow background playback of audiobooks.

[unreleased]: https://github.com/readium/r2-streamer-swift/compare/master...HEAD
[2.0.0-alpha.1]: https://github.com/readium/r2-streamer-swift/compare/1.2.5...2.0.0-alpha.1
