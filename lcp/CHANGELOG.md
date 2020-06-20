# Changelog

All notable changes to this project will be documented in this file.

**Warning:** Features marked as *experimental* may change or be removed in a future release without notice. Use with caution.

## [Unreleased]

### Added

* Support for [PDF](https://readium.org/lcp-specs/notes/lcp-for-pdf.html) and [Readium Audiobooks](https://readium.org/lcp-specs/notes/lcp-for-audiobooks.html) protected with LCP.

### Changed

* `LCPAuthenticating` can now return hashed passphrases in addition to clear ones. [This can be used by reading apps](https://github.com/readium/r2-lcp-swift/pull/75) fetching hashed passphrases from a web service or [Authentication for OPDS](https://readium.org/lcp-specs/notes/lcp-key-retrieval.html), for example.
* Provided `LCPAuthenticating` instances are now retained by the LCP service. Therefore, you can provide one without keeping a reference around in your own code.


[unreleased]: https://github.com/readium/r2-lcp-swift/compare/master...HEAD
[x.x.x]: https://github.com/readium/r2-lcp-swift/compare/1.2.3...x.x.x
