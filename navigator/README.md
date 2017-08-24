[![BSD-3](https://img.shields.io/badge/License-BSD--3-brightgreen.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
# r2-navigator-swift

A Swift implementation of the Readium-2 streamer

## Adding the library to your iOS project

##### Carthage

Add the following line to your Cartfile

`github "readium/r2-navigator-swift"`

Then run `carthage update --platform ios` to fetch and build the dependencies.

## Installing dependencies (for developers)

The project dependencies are managed with [Carthage](https://github.com/Carthage/Carthage). 

Run `carthage update --platform ios` to fetch and build the dependencies:

  - [r2-shared-swift](https://github.com/readium/r2-shared-swift) : Contains the definitions of shared custom types used across the readium-2 Swift projects.
