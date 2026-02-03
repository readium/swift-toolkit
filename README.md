# Readium Swift Toolkit

[Readium Mobile](https://github.com/readium/mobile) is a toolkit for ebooks, audiobooks and comics written in Swift & Kotlin.

> [!TIP]
> **Take a look at the [guide to quickly get started](docs/Guides/Getting%20Started.md).** A [Test App](TestApp) demonstrates how to integrate the Readium Swift toolkit in your own reading app.

## Features

✅ Implemented &nbsp;&nbsp;&nbsp;&nbsp; 🚧 Partially implemented  &nbsp;&nbsp;&nbsp;&nbsp; 📆 Planned &nbsp;&nbsp;&nbsp;&nbsp; 👀 Want to do &nbsp;&nbsp;&nbsp;&nbsp; ❌ Not planned

### Formats

#### Ebook and Document Formats

| Format                                                 | Status |
|--------------------------------------------------------|:------:|
| EPUB (reflowable)                                      |   ✅   |
| EPUB (fixed-layout)                                    |   ✅   |
| PDF                                                    |   ✅   |
| Readium Web Publication                                |   🚧   |
| [DAISY](https://daisy.org/activities/standards/daisy/) |   👀   |

#### Audiobook Formats

| Format                                                 | Status |
|--------------------------------------------------------|:------:|
| Readium Audiobook                                      |   ✅   |
| Zipped Audiobook                                       |   ✅   |
| Standalone audio files (MP3, AAC, etc.)                |   ✅   |
| [DAISY](https://daisy.org/activities/standards/daisy/) |   👀   |

#### Comic Formats

| Format               | Status |
|----------------------|:------:|
| Readium Divina       |   ✅   |
| CBZ (Comic Book ZIP) |   ✅   |
| CBR (Comic Book RAR) |   ❌   |

### Features

A number of features are implemented only for some publication formats.

| Feature                       | EPUB (reflow) | EPUB (FXL) | PDF |
|-------------------------------|:-------------:|:----------:|:---:|
| Pagination                    |       ✅      |     ✅     |  ✅ |
| Scrolling                     |       ✅      |     👀     |  ✅ |
| Right-to-left (RTL)           |       ✅      |     ✅     |  ✅ |
| Search in textual content     |       ✅      |     ✅     |  👀 |
| Highlighting (Decoration API) |       ✅      |     ✅     |  👀 |
| Text-to-speech (TTS)          |       ✅      |     ✅     |  👀 |
| Media overlays                |       📆      |     📆     |     |

### OPDS Support

| Feature                                                                                           | Status |
|---------------------------------------------------------------------------------------------------|:------:|
| [OPDS Catalog 1.2](https://specs.opds.io/opds-1.2)                                                |   ✅   |
| [OPDS Catalog 2.0](https://drafts.opds.io/opds-2.0)                                               |   ✅   |
| [Authentication for OPDS](https://drafts.opds.io/authentication-for-opds-1.0.html)                |   📆   |
| [OPDS Progression](https://github.com/opds-community/drafts/pull/91)                              |   📆   |
| [Readium LCP Automatic Key Retrieval](https://readium.org/lcp-specs/notes/lcp-key-retrieval.html) |   📆   |

### DRM Support

| Feature                                                                   | Status |
|---------------------------------------------------------------------------|:------:|
| [Readium LCP](https://www.edrlab.org/projects/readium-lcp/)               |   ✅   |
| [Adobe ACS](https://www.adobe.com/fr/solutions/ebook/content-server.html) |   ❌   |


## User Guides

Guides are available to help you make the most of the toolkit.

### Publication

* [Opening a publication](docs/Guides/Open%20Publication.md) – parse a publication package (EPUB, PDF, etc.) or manifest (RWPM) into Readium `Publication` models
* [Extracting the content of a publication](docs/Guides/Content.md) – API to extract the text content of a publication for searching or indexing it
* [Text-to-speech](docs/Guides/TTS.md) – read aloud the content of a textual publication using speech synthesis
* [Accessibility](docs/Guides/Accessibility.md) – inspect accessibility metadata and present it to users


### Navigator

* [Navigator](docs/Guides/Navigator/Navigator.md) - an overview of the Navigator to render a `Publication`'s content to the user
* [Configuring the Navigator](docs/Guides/Navigator/Preferences.md) – setup and render Navigator user preferences (font size, colors, etc.)
* [Font families in the EPUB navigator](docs/Guides/Navigator/EPUB%20Fonts.md) – support custom font families with reflowable EPUB publications
* [Integrating the Navigator with SwiftUI](docs/Guides/Navigator/SwiftUI.md) – glue to setup the Navigator in a SwiftUI application

### DRM

* [Supporting Readium LCP](docs/Guides/Readium%20LCP.md) – open and render LCP DRM protected publications

## Setting up the Readium Swift toolkit

### Minimum Requirements

<!-- https://swiftversion.net/ -->

| Readium   | iOS  | Swift compiler | Xcode |
|-----------|------|----------------|-------|
| `develop` | 13.4 | 6.0            | 16.2  |
| 3.0.0     | 13.4 | 5.10           | 15.4  |
| 2.5.1     | 11.0 | 5.6.1          | 13.4  |
| 2.5.0     | 10.0 | 5.6.1          | 13.4  |
| 2.4.0     | 10.0 | 5.3.2          | 12.4  |


### Dependencies

The toolkit's libraries are distributed with [Swift Package Manager](#swift-package-manager) (recommended), [Carthage](#carthage) and [CocoaPods](#cocoapods). It's also possible to clone the repository (or a fork) and [depend on the libraries locally](#local-git-clone).

The [Test App](TestApp) contains examples on how to use all these dependency managers.

#### Swift Package Manager

From Xcode, open **File** > **Add Packages** and use Readium's GitHub repository for the package URL: `https://github.com/readium/swift-toolkit.git`.

You are then free to add one or more Readium libraries to your application. They are designed to work independently.

If you're stuck, find more information at [developer.apple.com](https://developer.apple.com/documentation/swift_packages/adding_package_dependencies_to_your_app).

#### Carthage

Add the following to your `Cartfile`:

```
github "readium/swift-toolkit" ~> 3.6.0
```

Then, [follow the usual Carthage steps](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application) to add the Readium libraries to your project.

Note that Carthage will build all Readium modules and their dependencies, but you are free to add only the ones you are actually using. The Readium libraries are designed to work independently.

Refer to the following table to know which dependencies are required for each Readium library.

|                        |   `ReadiumShared`  |  `ReadiumStreamer` | `ReadiumNavigator` |    `ReadiumOPDS`   |    `ReadiumLCP`    | `ReadiumAdapterGCDWebServer` | `ReadiumAdapterLCPSQLite` |
|------------------------|:------------------:|:------------------:|:------------------:|:------------------:|:------------------:|------------------------------|---------------------------|
| **`ReadiumShared`**    |                    | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark:           | :heavy_check_mark:        |
| **`ReadiumInternal`**  | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |                              |                           |
| `CryptoSwift`          |                    | :heavy_check_mark: |                    |                    | :heavy_check_mark: |                              |                           |
| `DifferenceKit`        |                    |                    | :heavy_check_mark: |                    |                    |                              |                           |
| `ReadiumFuzi`          | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |                              |                           |
| `ReadiumGCDWebServer`  |                    |                    |                    |                    |                    | :heavy_check_mark:           |                           |
| `ReadiumZIPFoundation` | :heavy_check_mark: |                    |                    |                    | :heavy_check_mark: |                              |                           |
| `Minizip`              | :heavy_check_mark: |                    |                    |                    |                    |                              |                           |
| `SQLite.swift`         |                    |                    |                    |                    |                    |                              | :heavy_check_mark:        |
| `SwiftSoup`            | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |                              |                           |

#### CocoaPods

Add the following `pod` statements to your `Podfile` for the Readium libraries you want to use:

```
source 'https://github.com/readium/podspecs'
source 'https://cdn.cocoapods.org/'

pod 'ReadiumShared', '~> 3.6.0'
pod 'ReadiumStreamer', '~> 3.6.0'
pod 'ReadiumNavigator', '~> 3.6.0'
pod 'ReadiumOPDS', '~> 3.6.0'
pod 'ReadiumLCP', '~> 3.6.0'
```

Take a look at [CocoaPods's documentation](https://guides.cocoapods.org/using/using-cocoapods.html) for more information.

#### Local Git Clone

You may prefer to use a local Git clone if you want to contribute to Readium, or if you are using your own fork.

First, add the repository as a Git submodule of your app repository, then checkout the desired branch or tag:

```sh
git submodule add https://github.com/readium/swift-toolkit.git
```

Next, drag and drop the whole `swift-toolkit` folder into your project to import Readium as a Swift Package.

Finally, add the Readium libraries you want to use to your app target from the **General** tab, section **Frameworks, Libraries, and Embedded Content**.

### Building with Readium LCP

Using the toolkit with Readium LCP requires additional dependencies, including the framework `R2LCPClient.framework` provided by EDRLab. [Contact EDRLab](mailto:contact@edrlab.org) to request your private `R2LCPClient.framework` and the setup instructions.

## Credits

This project is tested with BrowserStack.
