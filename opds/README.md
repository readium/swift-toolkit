# OPDS Parser (Swift)

[![License](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](/LICENSE)

A parser for OPDS 1.x and 2.0 written in Swift using the [Readium-2 shared model](https://github.com/readium/r2-shared-swift) 
and [Readium Web Publication Manifest](https://github.com/readium/webpub-manifest).

[Changes and releases are documented in the Changelog](CHANGELOG.md)

## Features

- [x] Abstract model
- [x] OPDS 1.x support
- [x] OPDS 2.0 support
- [x] Search
- [x] Full entries
- [x] Facets
- [x] Groups
- [x] Indirect acquisition
- [ ] Library specific extensions

## Getting started

## Adding the library to your iOS project

> _Note:_ requires Swift 4.2 (and Xcode 10.1).

### Carthage

[Carthage][] is a simple, decentralized dependency manager for Cocoa. To
install ReadiumOPDS with Carthage:

 1. Make sure Carthage is [installed][Carthage Installation].

 2. Update your Cartfile to include the following:

    ```ruby
    github "readium/r2-opds-swift" "develop"
    ```

 3. Run `carthage update --use-xcframeworks` and
    [add the appropriate framework][Carthage Usage].


[Carthage]: https://github.com/Carthage/Carthage
[Carthage Installation]: https://github.com/Carthage/Carthage#installing-carthage
[Carthage Usage]: https://github.com/Carthage/Carthage#adding-frameworks-to-an-application


#### Import

In your Swift files:

```Swift
// Swift source file

import ReadiumOPDS
```

#### Dependencies in this module

  - [R2Shared](https://github.com/readium/r2-shared-swift) : Custom types shared by several readium-2 Swift modules.
  - [Fuzi](https://github.com/edrlab/Fuzi) : A fast & lightweight XML & HTML parser in Swift with XPath & CSS support.

Modifications needed in Xcode:

In `Build Settings`, find `Search Paths`, add `$(SDKROOT)/usr/include/libxml2` to `Header Search Paths`.

### Usage

Parsing an OPDS feed (v1.x or 2.x):

```Swift
import ReadiumOPDS

let myURL = URL(string: "https://your/custom/url")
var parseData: ParseData?

override func viewDidLoad() {
    super.viewDidLoad()
    
    // Fetch and parse data from the specified URL
    OPDSParser.parseURL(url: myURL) { data, error in
        if let data = data {
            // parseData property holds the OPDS related data
            self.parseData = data
        }
    }
}

func refreshUI() {
  // Custom method
}
```

### API

#### Version

```Swift
/// List of OPDS versions compliant with the parser.
public enum Version {
    /// OPDS 1.x must be an XML ressource
    case OPDS1
    /// OPDS 2.x must be a JSON ressource
    case OPDS2
}
```

#### ParseData structure

```Swift
/// An intermediate structure return when the generic helper method public static
/// func parseURL(url: URL, completion: (ParseData?, Error?) -> Void) from OPDSParser class is called.
public struct ParseData {
    /// The ressource URL
    public var url: URL
    
    /// The URLResponse got after fetching the ressource
    public var response: URLResponse
    
    /// The OPDS version
    public var version: Version
    
    /// The feed (nil if publication is not)
    public var feed: Feed?
    
    /// The publication (nil if feed is not)
    public var publication: Publication?
}
```

#### OPDSParser class

```Swift
/// Parse an OPDS feed or publication.
/// Feed can be v1 (XML) or v2 (JSON).
/// - parameter url: The feed URL
public static func parseURL(url: URL, completion: (ParseData?, Error?) -> Void)
```
