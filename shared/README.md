# r2-shared-swift
Contains the definitions of the custom types (model) used across the readium-2 Swift projects.

## Add this library to your project
#### Carthage:
Add the following line to your `Cartfile` : `github "re-shared-swift" ~> 1.1`

## Installing dependencies (for developers)

The project dependencies are managed with [Carthage](https://github.com/Carthage/Carthage). 

Run `carthage update --platform ios` to fetch and build the dependencies:

  - [ObjectMapper](https://github.com/Hearst-DD/ObjectMapper) : ObjectMapper is a framework written in Swift that makes it easy for you to convert your model objects (classes and structs) to (and from JSON, but not used here).
