# Readium Swift Toolkit

[Readium Mobile](https://github.com/readium/mobile) is a toolkit for ebooks, audiobooks and comics written in Swift & Kotlin.

> [!TIP]
> **Take a look at the [guide to get started](docs/Guides/Getting%20Started.md).** A [Test App](TestApp) demonstrates how to integrate the Readium Swift toolkit in your own reading app.

This toolkit is a modular project, which follows the [Readium Architecture](https://github.com/readium/architecture).

* [`ReadiumShared`](Sources/Shared) – Shared `Publication` models and utilities
* [`ReadiumStreamer`](Sources/Streamer) – Publication parsers and local HTTP server
* [`ReadiumNavigator`](Sources/Navigator) – Plain `UIViewController` classes rendering publications
* [`ReadiumOPDS`](Sources/OPDS) – Parsers for OPDS catalog feeds
* [`ReadiumLCP`](Sources/LCP) – Service and models for [Readium LCP](https://www.edrlab.org/readium-lcp/)

## Minimum Requirements

<!-- https://swiftversion.net/ -->

| Readium   | iOS  | Swift compiler | Xcode |
|-----------|------|----------------|-------|
| `develop` | 13.4 | 5.10           | 15.4  |
| 3.0.0     | 13.4 | 5.10           | 15.4  |
| 2.5.1     | 11.0 | 5.6.1          | 13.4  |
| 2.5.0     | 10.0 | 5.6.1          | 13.4  |
| 2.4.0     | 10.0 | 5.3.2          | 12.4  |

## Using Readium

<!--:question: **Find documentation and API reference at [readium.org/kotlin-toolkit](https://readium.org/swift-toolkit)**.-->

Readium libraries are distributed with [Swift Package Manager](#swift-package-manager) (recommended), [Carthage](#carthage) and [CocoaPods](#cocoapods). It's also possible to clone the repository (or a fork) and [depend on the libraries locally](#local-git-clone).

The [Test App](TestApp) contains examples on how to use all these dependency managers.

### Swift Package Manager

From Xcode, open **File** > **Add Packages** and use Readium's GitHub repository for the package URL: `https://github.com/readium/swift-toolkit.git`.

You are then free to add one or more Readium libraries to your application. They are designed to work independently.

If you're stuck, find more information at [developer.apple.com](https://developer.apple.com/documentation/swift_packages/adding_package_dependencies_to_your_app).

### Carthage

Add the following to your `Cartfile`:

```
github "readium/swift-toolkit" ~> 3.2.0
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

### CocoaPods

Add the following `pod` statements to your `Podfile` for the Readium libraries you want to use:

```
source 'https://github.com/readium/podspecs'
source 'https://cdn.cocoapods.org/'

pod 'ReadiumShared', '~> 3.2.0'
pod 'ReadiumStreamer', '~> 3.2.0'
pod 'ReadiumNavigator', '~> 3.2.0'
pod 'ReadiumOPDS', '~> 3.2.0'
pod 'ReadiumLCP', '~> 3.2.0'
```

Take a look at [CocoaPods's documentation](https://guides.cocoapods.org/using/using-cocoapods.html) for more information.

### Local Git Clone

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
