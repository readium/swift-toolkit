# r2-streamer-swift
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

## Testing the project with the r2-launcher-swift (iOS)

- Clone this project (r2-streamer-swift) and the launcher ([r2-launcher-swift](https://github.com/readium/r2-launcher-swift))
- In each project directories run : `$> carthage update --platform ios` 
- Create a new XCode workspace and drag the two aforementioned project's `.xcodeproj` in the navigator panel on the left.
- Select the `R2-Launcher-Development` target and `Run` it on navigator or device.

NB: Choose the same branches on both r2-streamer/launcher repositories. E.g: `r2-streamer-swift/feature/X with r2-launcher-swift/feature/X`

## UnitTesting framework included in it (Work in progress)

- `$> carthage update --platform ios`
- run the testing project target from Xcode

## Dependencies

The project dependencies are managed with [Carthage](https://github.com/Carthage/Carthage).
You need to run `carthage update --platform ios` to fetch the dependencies and build their libraries/frameworks.

So far the project use :
- [swisspol/GCDWebServer](https://github.com/swisspol/GCDWebServer) A modern and lightweight GCD based HTTP 1.1 server designed to be embedded in OS X & iOS apps.
- [Hearst-DD/ObjectMapper](https://github.com/Hearst-DD/ObjectMapper) A framework written in Swift that makes it easy to convert your model objects (classes and structs) to and from JSON.
- [tadija/AEXML](https://github.com/tadija/AEXML) Simple and lightweight XML parser written in Swift.

## TODO
- NCX and Navigation Document parsing.
- Exhaustive metadata parsing.
- Add support Media Overlay.
- Fonts deobfuscation.
- Add support for content filters in the fetcher.
