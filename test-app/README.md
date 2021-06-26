# Readium Mobile Test App (Swift/iOS)

[![BSD-3](https://img.shields.io/badge/License-BSD--3-brightgreen.svg)](https://opensource.org/licenses/BSD-3-Clause)

This sample application demonstrates how to integrate the Readium 2 Swift toolkit in your own reading app. Stable versions are [published on TestFlight](https://testflight.apple.com/join/lYEMEfBr).

---

<div align="center">
<img src="https://media.giphy.com/media/hAttjic8neYp2/giphy.gif"/>
<img src="https://media.giphy.com/media/13ivNbjbbUT41a/giphy.gif"/>
<img src="https://media.giphy.com/media/l378cRkMNuKx2AOAw/giphy.gif"/>
</div>

## Features

- [x] EPUB 2.x and 3.x support
- [x] Readium LCP support
- [x] CBZ support
- [x] Custom styles
- [x] Night & sepia modes
- [x] Pagination and scrolling
- [x] Table of contents
- [x] OPDS 1.x and 2.0 support
- [x] EPUB fixed layout support
- [x] Right-to-left support

## Building the Test App

This project shows how to use Readium 2 with several dependency managers: Swift Package Manager, Carthage and CocoaPods. To simplify the setup, we use [XcodeGen](https://github.com/yonaskolb/XcodeGen) to automatically generate the Xcode project files for a given dependency manager.

1. Choose a type of project to generate:
    * `spm` for Swift Package Manager (recommended)
    * `carthage` for Carthage
    * `cocoapods` for CocoaPods
    * `dev` for Git submodules with Swift Package Manager
2. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) and the dependency manager you need.
3. Clone the project.
    ```sh
    git clone https://github.com/readium/r2-testapp-swift.git
    cd r2-testapp-swift
    ```
4. Generate the Xcode project using our `Makefile` and your target of choice. This will download all dependencies automatically.
    ```sh
    make spm
    ```
**Warning:** Since the Xcode project is not committed to this repository, you need to run the `make <target>` command again after pulling any change from `r2-testapp-swift`.

### Building with Readium LCP

Building with Readium LCP requires additional dependencies, including the binary `R2LCPClient.framework` provided by EDRLab.

1. [Contact EDRLab](mailto:contact@edrlab.org) to request your private `R2LCPClient.framework`.
2. If you integrate Readium 2 with Swift Package Manager or Git submodules, install [Carthage](https://github.com/Carthage/Carthage). `R2LCPClient.framework` is only available for Carthage or CocoaPods.
3. Generate the Xcode project with `make`, providing the URL given by EDRLab as the `url` parameter (`.json` for Carthage or SPM and `.podspec` for CocoaPods).
    ```sh
    make spm lcp=https://...json
    ```

## Integrating Readium 2 in your app

All migration steps necessary in reading apps to upgrade to major versions of the Readium toolkit are documented in the [migration guide](https://readium.org/mobile/swift/migration-guide).

The Readium 2 toolkit is split in several independent modules, following the [Readium Architecture](https://github.com/readium/architecture):

* [`r2-shared-swift`](https://github.com/readium/r2-shared-swift) – Shared `Publication` models and utilities
* [`r2-streamer-swift`](https://github.com/readium/r2-streamer-swift) – Publication parsers and local HTTP server
* [`r2-navigator-swift`](https://github.com/readium/r2-navigator-swift) – Plain view controllers rendering publications
* [`r2-opds-swift`](https://github.com/readium/r2-opds-swift) – Parsers for OPDS catalog feeds
* [`r2-lcp-swift`](https://github.com/readium/r2-lcp-swift) – Service and models for Readium LCP
* [`readium-css`](https://github.com/readium/readium-css) – CSS styles for EPUB publications

To understand how to integrate these dependencies in your project, take a look at the Xcode project created by `XcodeGen`. Or even better, check out the generated `project.yml` file which describes the structure of the Xcode project in a human-friendly way.

## Contributing

Follow the project on [ZenHub](https://app.zenhub.com/workspace/o/readium/r2-testapp-swift/boards).

The easiest way to contribute to the Readium 2 modules is to use the Git submodules integration.

```sh
make dev
```

