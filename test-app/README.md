# Readium-2 Test App (Swift/iOS) [![Available on the AppStore](https://devimages-cdn.apple.com/app-store/marketing/guidelines/images/badge-download-on-the-app-store.svg)](https://itunes.apple.com/us/app/r2-reader/id1363963230)

A test app for the Swift implementation of Readium-2. Stable builds are [published on the AppStore](https://itunes.apple.com/us/app/r2-reader/id1363963230).

Follow the project on [ZenHub](https://app.zenhub.com/workspace/o/readium/r2-testapp-swift/boards).

[![BSD-3](https://img.shields.io/badge/License-BSD--3-brightgreen.svg)](https://opensource.org/licenses/BSD-3-Clause)

## Features

- [x] EPUB 2.x and 3.x support
- [x] Readium LCP support
- [x] CBZ support
- [x] Custom styles
- [x] Night & sepia modes
- [x] Pagination and scrolling
- [x] Table of contents
- [x] OPDS 1.x and 2.0 support
- [ ] FXL support
- [ ] RTL support

## Demo

![](https://media.giphy.com/media/hAttjic8neYp2/giphy.gif) ![](https://media.giphy.com/media/13ivNbjbbUT41a/giphy.gif) ![](https://media.giphy.com/media/l378cRkMNuKx2AOAw/giphy.gif)

## Dependencies

- [Shared Models](https://github.com/readium/r2-shared-swift) (Model, shared for both streamer and navigator)
- [Streamer](https://github.com/readium/r2-streamer-swift) (The parser/server)
- [Navigator](https://github.com/readium/r2-navigator-swift) (The bare ViewControllers for displaying parsed resources)
- [Readium CSS](https://github.com/readium/readium-css) (Handles styles, layout and user settings)

## Install and run the testapp

1) If you're building the `develop` branch, change the Cartfile to use `develop` for all Readium-related dependencies :

```
github "readium/r2-shared-swift" "develop"
github "readium/r2-streamer-swift" "develop"
github "readium/r2-navigator-swift" "develop"
github "readium/readium-opds-swift" "develop"
```

2) Fetch the dependencies using [Carthage](https://github.com/Carthage/Carthage) :

`$> carthage update --platform ios`

3) Generate Carthage input/output filelist using [Carting](https://github.com/artemnovichkov/Carting) :

`$> carting update`

4) Open the Xcode project :

`$> open r2-testapp-swift.xcodeproj`

5) Build the project target named `r2-testapp-swift (carthage)`.

**More build and dependency information can be found in [r2-workspace-swift](https://github.com/readium/r2-workspace-swift)**

## [@Contributors] Efficient workflow for testing changes on Readium-2

The release target `r2-testapp-swift` uses the libraries and frameworks built by **Carthage**, while the debug `r2-testapp-swift-DEBUG` can be modified to use local versions of  **r2-shared-swift**, **r2-streamer-swift** and **r2-navigator-swift** depending of which you want to modify. Doing so will allow you to see the changes directly in the testapp, without the need for a Carthage cycle.

If you want to contribute to the development, I recommend creating a Workspace which contain the 4 projects (shared, streamer, navigator and testapp), and to use local Products as dependencies of the others to shorten development time.
e.g: in your local clone of **r2-navigator-swift**, create a debug target which uses the Product of your local clone of **r2-shared-swift**. That way, when you modify and compile **r2-shared-swift**, the modifications are directly taken in your next **r2-navigator-swift** build.
