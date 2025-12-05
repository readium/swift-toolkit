# Readium Test App (Swift/iOS)

This sample application demonstrates how to integrate the Readium Swift toolkit in your own reading app.

## Features

* Supported publication formats:
    * EPUB 2 and 3 (reflowable and fixed layout)
        * Custom styles
        * Night & sepia modes
    * CBZ
    * PDF
* Readium LCP support
* Pagination and scrolling
* Table of contents
* OPDS 1.x and 2.0 support
* Right-to-left support

## Building the Test App

This project shows how to use Readium with several dependency managers: Swift Package Manager, Carthage and CocoaPods. To simplify the setup, we use [XcodeGen](https://github.com/yonaskolb/XcodeGen) to automatically generate the Xcode project files for a given dependency manager.

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) and the dependency manager you need.
2. Clone the project.
    ```sh
    git clone https://github.com/readium/swift-toolkit.git
    cd swift-toolkit/TestApp
    ```
3. Choose a type of project to generate.
    * :warning: from the `main` branch only:
        * `spm` (recommended) Integration with Swift Package Manager
        * `carthage` Integration with Carthage
        * `cocoapods` Integration with CocoaPods
    * from the `main` or `develop` branches:
        * `dev` Integration with local folders and SPM, for contributors
4. Generate the Xcode project using the `Makefile` and your target of choice. This will download all the dependencies automatically.
    ```sh
    make spm
    ```

> [!IMPORTANT]
> Since the Xcode project is not committed to this repository, you need to run the `make <target>` command again after pulling any change from the repository.

### Building with Readium LCP

Building with Readium LCP requires additional dependencies, including the library `R2LCPClient.framework` provided by EDRLab.

1. [Contact EDRLab](mailto:contact@edrlab.org) to request your private `R2LCPClient.framework`.
2. If you integrate Readium with Swift Package Manager or Git submodules, install [Carthage](https://github.com/Carthage/Carthage). `R2LCPClient.framework` is only available for Carthage or CocoaPods.
3. Generate the Xcode project with `make`, providing the URL given by EDRLab as the `url` parameter (`Package.swift` for SPM, `liblcp.json` for Carthage and `latest.podspec` for CocoaPods).
    ```sh
    make spm lcp=https://.../Package.swift
    ```

