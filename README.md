# Readium Swift Toolkit

[Readium Mobile](https://github.com/readium/mobile) is a toolkit for ebooks, audiobooks and comics written in Swift & Kotlin.

This toolkit is a modular project, which follows the [Readium Architecture](https://github.com/readium/architecture).

* [`R2Shared`](Sources/Shared) – Shared `Publication` models and utilities
* [`R2Streamer`](Sources/Streamer) – Publication parsers and local HTTP server
* [`R2Navigator`](Sources/Navigator) – Plain `UIViewController` classes rendering publications
* [`ReadiumOPDS`](Sources/OPDS) – Parsers for OPDS catalog feeds
* [`ReadiumLCP`](Sources/LCP) – Service and models for [Readium LCP](https://www.edrlab.org/readium-lcp/)

A [Test App](TestApp) demonstrates how to integrate the Readium Swift toolkit in your own reading app

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
github "readium/swift-toolkit" ~> 2.4.0
```

Then, [follow the usual Carthage steps](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application) to add the Readium libraries to your project.

Note that Carthage will build all Readium modules and their dependencies, but you are free to add only the ones you are actually using. The Readium libraries are designed to work independently.

Refer to the following table to know which dependencies are required for each Readium library.

|                 | `R2Shared`         | `R2Streamer`       | `R2Navigator`      | `ReadiumOPDS`      | `ReadiumLCP`       |
|-----------------|:------------------:|:------------------:|:------------------:|:------------------:|:------------------:|
| **`R2Shared`**  |                    | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| `CryptoSwift`   |                    | :heavy_check_mark: |                    |                    | :heavy_check_mark: |
| `DifferenceKit` |                    |                    | :heavy_check_mark: |                    |                    |
| `Fuzi`          | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| `GCDWebServer`  |                    | :heavy_check_mark: |                    |                    |                    |
| `Minizip`       | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| `SQLite.swift`  |                    |                    |                    |                    | :heavy_check_mark: |
| `SwiftSoup`     | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| `ZIPFoundation` |                    |                    |                    |                    | :heavy_check_mark: |

### CocoaPods

Add the following `pod` statements to your `Podfile` for the Readium libraries you want to use:

```
pod 'R2Shared', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/2.4.0/Support/CocoaPods/ReadiumShared.podspec'
pod 'R2Streamer', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/2.4.0/Support/CocoaPods/ReadiumStreamer.podspec'
pod 'R2Navigator', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/2.4.0/Support/CocoaPods/ReadiumNavigator.podspec'
pod 'ReadiumOPDS', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/2.4.0/Support/CocoaPods/ReadiumOPDS.podspec'
pod 'ReadiumLCP', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/2.4.0/Support/CocoaPods/ReadiumLCP.podspec'

# Required if you use R2Streamer.
pod 'GCDWebServer', podspec: 'https://raw.githubusercontent.com/readium/GCDWebServer/3.7.3/GCDWebServer.podspec'
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
