[![BSD-3](https://img.shields.io/badge/License-BSD--3-brightgreen.svg)](https://opensource.org/licenses/BSD-3-Clause)
# r2-testapp-swift

A test app for the Swift implementation of Readium-2.
It showcase the use of the differents building blocks of Readium-2

![](https://media.giphy.com/media/hAttjic8neYp2/giphy.gif) ![](https://media.giphy.com/media/13ivNbjbbUT41a/giphy.gif) ![](https://media.giphy.com/media/JRVssNIC48Bb2/giphy.gif)

- [r2-shared-swift](https://github.com/readium/r2-shared-swift) (Model, shared for both streamer and navigator)
- [r2-streamer-swift](https://github.com/readium/r2-streamer-swift/blob/master/README.md) (The parser/server)
- [r2-navigator-swift](https://github.com/readium/r2-navigator-swift/blob/master/README.md) (The bare ViewControllers for displaying parsed resources)

## Install and run the testapp

1) Fetch the dependencies using [Carthage](https://github.com/Carthage/Carthage) : 

`$> carthage update --platform ios`

2) Open the xCode project :

`$> open r2-testapp-swift.xcodeproj`

3) Build the project target named `r2-testapp-swift`.

## [@Contributors] Efficient workflow for testing changes on Readium-2

The release target `r2-testapp-swift` uses the libraries and frameworks built by **Carthage**, while the debug `r2-testapp-swift-DEBUG` can be modified to use local version of  **r2-shared-swift**, **r2-streamer-swift** and **r2-navigator-swift** depending of which you want to modify. Doing so will allow you to see the changes directly in the testapp, without the need for a Carthage cycle.

If you want to contribute to the development, I recommend creating a Workspace which contain the 4 projects (shared, streamer, navigator and testapp), and to use local Products as dependancies of the others to shorten development time.
e.g: in your local clone of **r2-navigator-swift**, create a debug target which uses the Product of your local clone of **r2-shared-swift**. That way, when you modify and compile **r2-shared-swift**, the modifications are directly taken in your next **r2-navigator-swift** build.

