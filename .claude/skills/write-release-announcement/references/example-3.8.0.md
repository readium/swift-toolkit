# Example: 3.8.0 (focused release)

## Changelog

### Added

#### LCP

* New Keychain-based implementations of the LCP license and passphrase repositories: `LCPKeychainLicenseRepository` and `LCPKeychainPassphraseRepository`.
    * Stored securely in the iOS/macOS Keychain.
    * Persist across app reinstalls.
    * Optionally synchronized across devices via iCloud Keychain.

### Changed

#### Navigator

* The EPUB navigator no longer requires an HTTP server. Publication resources are now served directly to the web views using a custom URL scheme handler.
    * The `httpServer` parameter of `EPUBNavigatorViewController` is deprecated and ignored.

### Deprecated

#### Navigator

* `CBZNavigatorViewController` is now deprecated.
    * Open CBZ publications with `EPUBNavigatorViewController` instead, which has more configuration options and preferences.

#### LCP

* `ReadiumAdapterLCPSQLite` is now deprecated in favor of the built-in Keychain repositories. See [the migration guide](docs/Migration%20Guide.md) for instructions.

### Fixed

* Fixed casting of `ResourceProperties`'s `mediaType` (contributed by [@lbeus](https://github.com/readium/swift-toolkit/pull/719)).

#### Navigator

* The first resource of a fixed-layout EPUB is now displayed on its own by default, matching Apple Books behavior.
* Fixed the default spread position for single fixed-layout EPUB spreads that are not the first page.

#### LCP

* Fixed the `print` method consuming copy rights instead of print rights.

## Blog Post

We are happy to announce a new update to the Swift toolkit, which focuses on strengthening the security of LCP repositories and improving the reading experience for Fixed-Layout (FXL) EPUBs.

### Secure LCP Repositories with Keychain

This version introduces new `LCPKeychainLicenseRepository` and `LCPKeychainPassphraseRepository` implementations backed by the iOS Keychain. This move from a local database to the system Keychain offers several benefits:

* **Enhanced Security:** Your users' licenses and passphrases are now stored with the highest level of security provided by the OS.
* **iCloud Synchronization:** Repositories can now optionally be synchronized via iCloud Keychain, allowing users to seamlessly access their content across multiple devices.
* **Persistence:** Data remains secure even if the app is reinstalled.

With these new native implementations, the old SQLite-based repositories are now deprecated. We have provided a migration tool to help you transition your existing data to the new Keychain repositories seamlessly.

### Lighter EPUB Navigator

We have removed the dependency on an embedded HTTP server for the EPUB navigator. Resources are now served directly to the web views using a custom URL scheme handler. This architectural change makes the EPUB navigator both lighter and more secure by reducing the attack surface.

**Note:** While the HTTP server is no longer required for EPUBs, it remains necessary for rendering PDF documents.

### Improved FXL EPUB Support

We improved the reading experience for Fixed-Layout (FXL) EPUBs.

* **Better Spreads:** We have refined the layout logic for spreads to match the behavior users expect from native apps like Apple Books. This includes defaulting to displaying the first resource on its own and fixing spread positioning for single pages later in the book.
* **CBZNavigator Deprecation:** The `CBZNavigatorViewController` has been deprecated. We now recommend opening CBZ publications using the `EPUBNavigatorViewController`. The EPUB navigator has matured to the point where it offers better configuration options and preference handling than the specialized CBZ navigator.

## Discord

We are happy to announce a new update to the Swift toolkit, which focuses on strengthening the security of LCP repositories and improving the reading experience for Fixed-Layout (FXL) EPUBs.

Along with this release, we are also excited to launch our brand new documentation website. You can now find the complete API reference and user guides at https://readium.org/swift-toolkit.

https://blog.readium.org/release-note-swift-toolkit-version-3-8-0/
