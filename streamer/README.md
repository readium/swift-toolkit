[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

R2-streamer-swift aims at simplifying the usage of numeric publication by parsing and serving them.
It takes the publication as input, and generates an accessible [WebPubManifest](https://github.com/readium/webpub-manifest)/object as output.

# Get started

## Adding the library to your iOS project

##### Carthage

Add the following line to your Cartfile

`github "readium/r2-streamer-swift" "master"`

Then run `carthage update --platform ios` to fetch and build the dependencies.

##### CocoaPods

//Todo

##### Import

In your Swift files :

```Swift
// Swift source file

import R2Streamer
```

# Parsing publications

##### EPUB
`let parser = EpubParser()`

##### CBZ
`let parser = CbzParser()`

##### Parsing
```Swift
...
var parseResult: PubBox

do {
    parseResult = try parser.parse(fileAtPath: path)
} catch {
    // `{Type}ParserError` exception handling
}

/// Get `Publication` from the `parseResult`
let publication = parseResult.publication

/// Access `Publication` content
let metadata = publication.metadata
let tableOfContent = publication.tableOfContent
let spineItems = publication.spine
//...
```

You can now access your publications content programmatically. The `Publication` object is described in the R2Streamer documentation [LINK].

# Built in HTTP server

##### Initializing the server
R2Streamer provides, for convenience, a local HTTP server called `PublicationSever`.

```Swift
/// Instantiation of the HTTP server
guard let publicationServer = PublicationServer() else {
    // Error
}
```

##### Adding publications to the server
You can add your parsed publication to the server at the desired endpoints. (The endpoint parameter is optional, an `UUID` will be generated if let empty as below)

```Swift
/// Adding a publication to the server (Using the above section variables)
do {
    try publicationServer.add(publication, with: container/* ,"customEndpoint" */)
} catch {
    // `PublicationServerError` exception handling
}
```

When a Publication is added to the server, a new 'self' `Link` is added to the `Publication`'s `links` property.
The `Publication` now know how to locate it's resources over HTTP. See below for an example.

##### Accessing a `Link` resource from the server
The `Publication` is described using `Link`s. Each link describe a resource from the publication in a Publication-relative way.

```Swift
/// Accessing any `Link` resource over HTTP
let cover = publication.coverLink // Or `spineItems[x]`...

let coverUri = publication.uri(forLink: cover)
print(coverUri) // "http://{serverip}:{serverport}/{endpoint}/{`cover.href`}"
```

##### Removing a publication from the server
Using the `Publication` itself:

`publicationServer.remove(publication)`

Or it's endpoint:

`publicationServer.remove(at: "endpoint")`

# WebPub Manifest

For further informations see [readium/webpub-manifest](https://github.com/readium/webpub-manifest).

##### Pretty
`publication.manifest()`

##### Canonical
`publication.manifestCanonical()`

_________

Supported formats: 

**EPUB 2/3/3.1- OEBPS - CBZ**

## Dependencies

The project dependencies are managed with [Carthage](https://github.com/Carthage/Carthage).
You need to run `carthage update (--platform ios)` to install them.

Using:
- [swisspol/GCDWebServer](https://github.com/swisspol/GCDWebServer) A modern and lightweight GCD based HTTP 1.1 server designed to be embedded in OS X & iOS apps.
- [Hearst-DD/ObjectMapper](https://github.com/Hearst-DD/ObjectMapper) A framework written in Swift that makes it easy to convert your model objects (classes and structs) to and from JSON.
- [tadija/AEXML](https://github.com/tadija/AEXML) Simple and lightweight XML parser written in Swift.
- [krzyzanowskim/CryptoSwift](https://github.com/krzyzanowskim/CryptoSwift) Crypto related functions and helpers for Swift implemented in Swift.

## Documentation

[Jazzy](https://github.com/realm/jazzy) is used to generate the project documentation.
There are two script for building either the Public API documentation of the full documentation.

    `./generate_doc_public.sh`
    `./generate_doc_full.sh`
