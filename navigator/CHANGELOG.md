# Changelog

All notable changes to this project will be documented in this file.

**Warning:** Features marked as *experimental* may change or be removed in a future release without notice. Use with caution.

## [Unreleased]

## [2.0.0-alpha.1]

### Added

* Support for pop-up footnotes (contributed by [@tooolbox](https://github.com/readium/r2-navigator-swift/pull/118)).
  * **This is an opt-in feature**. Reading apps can customize how footnotes are presented to the user by implementing `NavigatorDelegate.navigator(_:shouldNavigateToNoteAt:content:referrer:)`. [An example presenting footnotes in pop-ups is demonstrated in the Test App](https://github.com/readium/r2-testapp-swift/pull/328).
  * Footnotes' content is extracted with [scinfu/SwiftSoup](https://github.com/scinfu/SwiftSoup), which you may need to add to your app if you're not using Carthage or CocoaPods.
* In EPUB's user settings:
  * Support for hyphenation (contributed by [@ehapmgs](https://github.com/readium/r2-navigator-swift/pull/76)).
  * Publishers' default styles are now used by default.
  * Default line height is increased to improve readability.
* JavaScript errors are logged in Xcode's console for easier debugging.

### Changed

* [Upgraded to Readium CSS 1.0.0-beta.1.](https://github.com/readium/r2-navigator-swift/pull/125)
  * Two new fonts are available: AccessibleDfa and IA Writer Duospace.
  * The file structure now follows strictly the one from [ReadiumCSS's `dist/`](https://github.com/readium/readium-css/tree/master/css/dist), for easy upgrades and custom builds replacement.

### Fixed

* Jumping to a bookmark (`Locator`) located in a resource that is not already pre-loaded used to fail for some publications.
* Touching interactive elements in fixed-layout EPUBs, when two-page spreads are enabled.

[unreleased]: https://github.com/readium/r2-navigator-swift/compare/master...HEAD
[2.0.0-alpha.1]: https://github.com/readium/r2-navigator-swift/compare/1.2.6...2.0.0-alpha.1
