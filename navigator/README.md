[![BSD-3](https://img.shields.io/badge/License-BSD--3-brightgreen.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
# r2-navigator-swift

A Swift implementation of the R2 Navigator

## Adding the library to your iOS project

> _Note:_ requires Swift 4.2 (and Xcode 10.1).

### Carthage

[Carthage][] is a simple, decentralized dependency manager for Cocoa. To
install R2Navigator with Carthage:

 1. Make sure Carthage is [installed][Carthage Installation].

 2. Update your Cartfile to include the following:

    ```ruby
    github "readium/r2-navigator-swift" ~> 1.0.6
    ```

 3. Run `carthage update` and
    [add the appropriate framework][Carthage Usage].


[Carthage]: https://github.com/Carthage/Carthage
[Carthage Installation]: https://github.com/Carthage/Carthage#installing-carthage
[Carthage Usage]: https://github.com/Carthage/Carthage#adding-frameworks-to-an-application


### CocoaPods

[CocoaPods][] is a dependency manager for Cocoa projects. To install
R2Navigator with CocoaPods:

 1. Make sure CocoaPods is [installed][CocoaPods Installation]. (R2Navigator
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
        pod 'R2Navigator', :git => 'https://github.com/readium/r2-navigator-swift.git', '~> 1.0.6'
    end
    ```

 3. Run `pod install --repo-update`.

[CocoaPods]: https://cocoapods.org
[CocoaPods Installation]: https://guides.cocoapods.org/using/getting-started.html#getting-started

##### Import

In your Swift files :

```Swift
// Swift source file

import R2Navigator
```

## Dependencies in this module

  - [R2Shared](https://github.com/readium/r2-shared-swift) : Contains the definitions of shared custom types used across the readium-2 Swift projects.
