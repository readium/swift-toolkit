[![BSD-3](https://img.shields.io/badge/License-BSD--3-brightgreen.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
# r2-shared-swift

Contains the definitions of the custom types (model) used across the readium-2 Swift projects.

## Adding the library to your iOS project

##### Carthage

Add the following line to your Cartfile

`github "readium/r2-shared-swift"`

Then run `carthage update --platform ios` to fetch and build the dependencies.

##### Import

In your Swift files :

```Swift
// Swift source file

import R2Shared
```

## Installing dependencies (for developers)

The project dependencies are managed with [Carthage](https://github.com/Carthage/Carthage). 

Run `carthage update --platform ios` to fetch and build the dependencies:

  - [ObjectMapper](https://github.com/Hearst-DD/ObjectMapper) : ObjectMapper is a framework written in Swift that makes it easy for you to convert your model objects (classes and structs) to (and from JSON, but not used here).
