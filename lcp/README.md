# r2-lcp-swift

Swift wrapper module for LCP support

[Changes and releases are documented in the Changelog](CHANGELOG.md)

## Adding the library to your iOS project

> _Note:_ requires Swift 4.2 (and Xcode 10.1).

### Carthage

[Carthage][] is a simple, decentralized dependency manager for Cocoa. To
install ReadiumLCP with Carthage:

 1. Make sure Carthage is [installed][Carthage Installation].

 2. Update your Cartfile to include the following:

    ```ruby
    github "readium/r2-lcp-swift" "develop"
    ```

 3. Run `carthage update` and
    [add the appropriate framework][Carthage Usage].


[Carthage]: https://github.com/Carthage/Carthage
[Carthage Installation]: https://github.com/Carthage/Carthage#installing-carthage
[Carthage Usage]: https://github.com/Carthage/Carthage#adding-frameworks-to-an-application


### CocoaPods

[CocoaPods][] is a dependency manager for Cocoa projects. To install
ReadiumLCP with CocoaPods:

 1. Make sure CocoaPods is [installed][CocoaPods Installation]. (ReadiumLCP
    requires version 1.0.0 or greater.)

    ```sh
    # Using the default Ruby install will require you to use sudo when
    # installing and updating gems.
    [sudo] gem install cocoapods
    ```

 2. Update your Podfile to include the following:

    ```ruby
    use_frameworks!

    target 'YourAppTargetName' do
        pod 'ReadiumLCP', :git => 'https://github.com/readium/r2-lcp-swift.git', :branch => 'develop'
    end
    ```

 3. Run `pod install --repo-update`.

[CocoaPods]: https://cocoapods.org
[CocoaPods Installation]: https://guides.cocoapods.org/using/getting-started.html#getting-started

### Dependencies in this module

  - [R2Shared](https://github.com/readium/r2-shared-swift) : Custom types shared by several readium-2 Swift modules.
  - [ZIPFoundation](https://github.com/edrlab/ZIPFoundation) : Effortless ZIP Handling in Swift
  - [SQLite.swift](https://github.com/stephencelis/SQLite.swift) : A type-safe, Swift-language layer over SQLite3.
  - [CryptoSwift](https://github.com/krzyzanowskim/CryptoSwift) : CryptoSwift is a growing collection of standard and secure cryptographic algorithms implemented in Swift


