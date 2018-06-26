# OPDS Parser (Swift)
[![License](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](/LICENSE)

A parser for OPDS 1.x and 2.0 written in Swift using the [Readium-2 shared model](https://github.com/readium/r2-shared-swift) 
and [Readium Web Publication Manifest](https://github.com/readium/webpub-manifest).

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

### Adding the library to your iOS project

#### Carthage

Add the following line to your Cartfile

`github "readium/readium-opds-swift"`

Then run `carthage update --platform ios` to fetch and build the dependencies.

#### Import

In your Swift files:

```Swift
// Swift source file

import ReadiumOPDS
```

#### Installing dependencies (for developers)

The project dependencies are managed with [Carthage](https://github.com/Carthage/Carthage). 

Run `carthage update --platform ios` to fetch and build the dependencies:

  - [r2-shared-swift](https://github.com/readium/r2-shared-swift) : Custom types shared by several readium-2 Swift modules.
  - [PromiseKit](https://github.com/mxcl/PromiseKit) : Promises for Swift & ObjC.
  - [Fuzi](https://github.com/cezheng/Fuzi) : A fast & lightweight XML & HTML parser in Swift with XPath & CSS support.

Then, in Xcode:

In `Build Settings`, find `Search Paths`, add `$(SDKROOT)/usr/include/libxml2` to `Header Search Paths`.

### Usage

Parsing an OPDS feed (v1.x or 2.x):

```Swift
import ReadiumOPDS
import PromiseKit

let myURL = URL(string: "https://your/custom/url")
var parseData: ParseData?

override func viewDidLoad() {
    super.viewDidLoad()
    
    firstly {
      // Fetch and parse data from the specified URL
      OPDSParser.parseURL(url: myURL)
    }.then { newParseData -> Void in
      // parseData property holds the OPDS related data
      self.parseData = newParseData
    }.always {
      // Here, you can perform some checks on your own and refresh your UI
      self.refreshUI()
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
/// func parseURL(url: URL) -> Promise<ParseData> from OPDSParser class is called.
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
/// - Returns: A promise with the intermediate structure of type ParseData
public static func parseURL(url: URL) -> Promise<ParseData>
```