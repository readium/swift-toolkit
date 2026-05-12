# Example: 3.7.0 (feature-rich release)

## Changelog

### Added

#### Shared

* Added support for JXL (JPEG XL) bitmap images. JXL is decoded natively on iOS 17+.
* `Publication.cover()` now falls back on the first reading order resource if it's a bitmap image and no cover is declared.

#### Navigator

* Support for displaying Divina (image-based publications like CBZ) in the fixed-layout EPUB navigator.
* Bitmap images in the EPUB reading order are now supported as a fixed layout resource.
* Added `offsetFirstPage` preference for fixed-layout EPUBs to control whether the first page is displayed alone or alongside the second page when spreads are enabled.

#### Streamer

* The `ImageParser` now extracts metadata from `ComicInfo.xml` files in CBZ archives.
* EPUB manifest item fallbacks are now exposed as `alternates` in the corresponding `Link`.
* EPUBs with only bitmap images in the spine are now treated as Divina publications with fixed layout.
    * When an EPUB spine item is HTML with a bitmap image fallback (or vice versa), the image is preferred as the primary link.
* Standalone audio files (e.g. MP3) metadata extraction now includes `narrators` (from the composer metadata fields) and merges artist metadata into `authors`, following conventions used by common audiobook tools.

### Changed

* The iOS minimum deployment target is now iOS 15.0.

#### Shared

* Accessibility display strings are now sourced from the [thorium-locales](https://github.com/edrlab/thorium-locales/) repository (instead of W3C's repository). Contributions are welcome on [Weblate](https://hosted.weblate.org/projects/thorium-reader/publication-metadata/).

#### LCP

* The LCP dialog used by `LCPDialogAuthentication` has been redesigned.
    * **Breaking:** The LCP dialog localization string keys have been renamed. If you overrode these strings in your app, you must update them. [See the migration guide](docs/Migration%20Guide.md) for the key mapping.
* LCP localized strings are now sourced from the [thorium-locales](https://github.com/edrlab/thorium-locales/) repository. Contributions are welcome on [Weblate](https://hosted.weblate.org/projects/thorium-reader/readium-lcp/).

### Deprecated

#### Streamer

* The EPUB manifest item `id` attribute is no longer exposed in `Link.properties`.
* Removed title inference based on folder names within image and audio archives. Use the archive's filename instead.

### Fixed

#### Navigator

* PDF documents are now opened off the main thread, preventing UI freezes with large files.
* Fixed providing a custom reading order to the `EPUBNavigatorViewController` (contributed by [@lbeus](https://github.com/readium/swift-toolkit/pull/694)).

## Blog Post

We are pleased to release the Readium Swift Toolkit 3.7.0. This update brings significant improvements to how comics are handled, improves performance for large documents, and streamlines our localization sources.

### Improved reading for comics and image-based publications

This release focuses heavily on improving the reading experience for image-based publications. Firstly, we have added support for JXL (JPEG XL) bitmap images, allowing for high-quality images at smaller file sizes. Please note that JXL is decoded natively on iOS 17+.

Furthermore, you can now display Divina publications and CBZ files directly within the fixed-layout EPUB navigator. The toolkit now also recognizes EPUB files that consist solely of bitmap images and treats them as Divina publications. Additionally, we now extract metadata from `ComicInfo.xml` files in CBZ archives, ensuring better cataloging for comics.

Finally, we've introduced cover fallbacks. If a publication doesn't have a declared cover, the toolkit will now automatically use the first resource in the reading order as the cover (provided it is a bitmap image).

### Performance improvements for the Navigator

In this version, we've introduced a few improvements for the Navigator. First off, to prevent UI freezes when loading large files and for a smoother experience, PDF documents are now opened off the main thread.

Secondly, we've added a new `offsetFirstPage` preference for fixed-layout EPUBs. This gives you control over whether the first page appears alone or alongside the second page when spreads are enabled.

### Enhanced metadata for audio publications

For those building audiobook experiences, we've improved metadata extraction for standalone audio files (e.g., MP3s). The parser now extracts narrators and merges artist metadata into `authors`, aligning with conventions used by popular audiobook tools.

### Technical updates and breaking changes

The 3.7.0 version of the toolkit comes with some important information to note.

* **Deployment target minimum:** Please note that the minimum deployment target is now iOS 15.0.
* **Localization sources:** We have moved our accessibility and LCP localized strings to the thorium-locales repository to centralize translation efforts.
* **LCP Dialog Redesign:** The authentication dialog has been redesigned. This includes a breaking change regarding localization keys. If your app overrides these strings, please check the migration guide to update your key mappings.

## Discord

[Readium Swift Toolkit 3.7.0](https://github.com/readium/swift-toolkit/releases/tag/3.7.0) brings significant comic handling improvements, better performance, and streamlines localization.

### Comics

- **JPEG XL:** Added JXL support for high-quality, smaller images (native on iOS 17+).
- **Navigator:** Display Divina and CBZ files directly in the fixed-layout EPUB navigator.
- **Smart Handling:** Image-only EPUBs are treated as Divina. We now extract `ComicInfo.xml` metadata from CBZ.
- **Covers:** If no cover is declared, the first image acts as the fallback.

### Navigator & Performance

- **PDF:** Docs open off the main thread to prevent UI freezes.
- **Spreads:** New `offsetFirstPage` preference controls if the first page appears alone in spreads.

### Audio Metadata

Improved extraction for standalone audio. The parser extracts `narrators` and merges `artist` into `authors`.

### Technical Updates

- **iOS 15:** Minimum deployment target is now iOS 15.0.
- **Localization:** Accessibility and LCP strings moved to [`thorium-locales`](https://github.com/edrlab/thorium-locales/).
- **LCP Dialog:** Redesigned. **Breaking:** Localization keys changed. If overriding strings, check the migration guide.

https://blog.readium.org/release-note-swift-toolkit-version-3-7-0/
