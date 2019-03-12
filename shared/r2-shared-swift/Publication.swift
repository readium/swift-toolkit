//
//  Publication.swift
//  r2-shared-swift
//
//  Created by Olivier Körner on 08/12/2016.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// The representation of EPUB publication, with its metadata, its readingOrder item and
/// other resources.
/// It is created by the `EpubParser` from an EPUB file or directory.
/// As it extends `Encodable`, it can be serialized to `JSON`.
public class Publication {
    /// The version of the publication, if the type needs any.
    public var version: Double
    /// The metadata (title, identifier, contributors, etc.).
    public var metadata: Metadata
    /// Link to special ressources which are added to the publication.
    public var links = [Link]()
    /// Links of the readingOrder items of the publication.
    public var readingOrder = [Link]()
    /// Link to the ressources of the publication.
    public var resources = [Link]()
    /// Table of content of the publication.
    public var tableOfContents = [Link]()
    public var landmarks = [Link]()
    public var listOfAudioFiles = [Link]()
    public var listOfIllustrations = [Link]()
    public var listOfTables = [Link]()
    public var listOfVideos = [Link]()
    public var pageList = [Link]()
    /// OPDS
    public var images = [Link]()
    /// User properties
    public var userProperties = UserProperties()
    
    /// The updated date of file which is referenced by this Publication
    public var updatedDate:Date = Date() // default value to avoid optional chain

    /// Extension point for links that shouldn't show up in the manifest.
    public var otherLinks = [Link]()
    // TODO: other collections
    // var otherCollections: [PublicationCollection]
    public var internalData = [String: String]()
    
    // The status of Settings properties. Enable or disable.
    public var userSettingsUIPreset: [ReadiumCSSName: Bool]? {
        didSet {
            userSettingsUIPresetUpdated?(userSettingsUIPreset)
        }
    }
    
    public var userSettingsUIPresetUpdated:(([ReadiumCSSName: Bool]?) -> Void)?

    // MARK: - Public methods.

    /// A link to the publication's cover.
    /// The implementation scans the `links` for a link (readingOrder/resources/links) where `rel` is `cover`.
    /// If none is found, it is `nil`.
    public var coverLink: Link? {
        get {
            return link(withRel: "cover")
        }
    }

    /// Return the publication base URL based on the selfLink.
    /// e.g.: "http://localhost:8000/publicationName/".
    lazy public var baseUrl: URL? = {
        guard let selfLink = self.link(withRel: "self") else {
            print("Error: no selfLink found in publication.")
            return nil
        }
        let selfLinkHref = selfLink.href
        guard var pubBaseUrl = URL(string: selfLinkHref)?.deletingLastPathComponent() else
        {
            print("Error: invalid publication self link")
            return nil
        }
        return pubBaseUrl
    }()

    /// Return the serialized JSON for the Publication object: the WebPubManifest
    /// (canonical).
    public var manifest: String {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting.insert(.prettyPrinted);
        
        guard let jsonData = try? jsonEncoder.encode(self),
            let json = String(data: jsonData, encoding: .utf8)
            else {
                return "{}"
        }
        
        // Unescape slashes
        return json.replacingOccurrences(of: "\\/", with: "/")
    }

    public var manifestCanonical: String {
        var manifest = manifestDictionnary
        // Remove links from the canonical manifest
        manifest.removeValue(forKey: CodingKeys.links.rawValue)
        
        var options = JSONSerialization.WritingOptions()
        if #available(iOS 11.0, *) {
            options.insert(.sortedKeys)
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: manifest, options: options),
            let json = String(data: jsonData, encoding: .utf8)
            else {
                return "{}"
        }
        
        // Unescape slashes
        return json.replacingOccurrences(of: "\\/", with: "/")
    }

    /// Returns the JSON dictionnary.
    public var manifestDictionnary: [String: Any] {
        guard let jsonData = try? JSONEncoder().encode(self),
              let manifestDict = try? JSONSerialization.jsonObject(with: jsonData),
              let manifest = manifestDict as? [String: Any]
        else {
            return [:]
        }
        
        return manifest
    }

    public init() {
        version = 0.0
        metadata = Metadata()
    }

    // Mark: - Public methods.

    /// Finds a resource (asset or readingOrder item) with a matching relative path.
    ///
    /// - Parameter path: The relative path to match
    /// - Returns: a link with its `href` equal to the path if any was found,
    ///            else `nil`
    public func resource(withRelativePath path: String) -> Link? {
        let matchingLinks = (readingOrder + resources)

        return matchingLinks.first(where: { $0.href == path })
    }


    /// Return a link from the readingOrder having the given Href.
    ///
    /// - Parameter href: The `href` being searched.
    /// - Returns: The corresponding `Link` if any.
    public func readingOrderLink(withHref href: String) -> Link? {
        return readingOrder.first(where: { $0.href == href })
    }

    /// Find the first Link having the given `rel` in the publications's [Link]
    /// properties: `resources`, `readingOrder`, `links`.
    ///
    /// - Parameter rel: The `rel` being searched.
    /// - Returns: The corresponding `Link`, if any.
    public func link(withRel rel: String) -> Link? {
        let findLinkWithRel: (Link) -> Bool = { link in
            link.rel.contains(rel)
        }
        return findLinkInPublicationLinks(where: findLinkWithRel)
    }

    /// Find the first Link having the given `href` in the publication's [Link]
    /// properties: `resources`, `readingOrder`, `links`.
    ///
    /// - Parameter rel: The `href` being searched.
    /// - Returns: The corresponding `Link`, if any.
    public func link(withHref href: String) -> Link? {
        let findLinkWithHref: (Link) -> Bool = { link in
            href == link.href
        }
        return findLinkInPublicationLinks(where: findLinkWithHref)
    }

    /// Generate an URI (URL) to a publication Link. Using selfLink.
    ///
    /// - Parameter link: The link to generate an URI for.
    /// - Returns: The generated URI or nil.
    public func uriTo(link: Link?) -> URL? {
        guard let link = link,
            let publicationBaseUrl = baseUrl else
        {
            return nil
        }
        let linkHref = link.href
        // Remove trailing "/" before appending the href (href are absolute
        // relative to the publication, hence start with a "/".
        let trimmedBaseUrlString = publicationBaseUrl.absoluteString.trimmingCharacters(in: ["/"])
        guard let trimmedBaseUrl = URL(string: trimmedBaseUrlString) else {
            return nil
        }
        return trimmedBaseUrl.appendingPathComponent(linkHref)
    }

    /// Append the self/manifest link to  links.
    ///
    /// - Parameters:
    ///   - endPoint: The URI prefix to use to fetch assets from the publication.
    ///   - baseUrl: The base URL of the HTTP server.
    public func addSelfLink(endpoint: String, for baseUrl: URL) {
        let publicationURL: URL
        let manifestPath = "\(endpoint)/manifest.json"

        publicationURL = baseUrl.appendingPathComponent(manifestPath, isDirectory: false)
        links.append(Link(
            href: publicationURL.absoluteString,
            type: "application/webpub+json",
            rels: ["self"]
        ))
    }

    // Mark: - Fileprivate Methods.
    
    /// Find the first link conforming to the passed closure, using `.where()`
    /// in the publications's [Link] properties: `resources`, `readingOrder`, `links`.
    ///
    /// - Parameter closure: The closure to conform to.
    /// - Returns: The corresponding Link found, if any.
    fileprivate func findLinkInPublicationLinks(where closure: (Link) -> Bool) -> Link? {
        if let link = resources.first(where: closure) {
            return link
        }
        if let link = readingOrder.first(where: closure) {
            return link
        }
        if let link = links.first(where: closure) {
            return link
        }
        return nil
    }
}

extension Publication: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case landmarks
        case links
        case listOfIllustrations = "loi"
        case listOfTables = "lot"
        case metadata
        case pageList = "page-list"
        case resources
        case readingOrder
        case tableOfContents = "toc"
    }
    
    public func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        if !landmarks.isEmpty {
//            try container.encode(landmarks, forKey: .landmarks)
//        }
//        if !links.isEmpty {
//            try container.encode(links, forKey: .links)
//        }
//        if !listOfIllustrations.isEmpty {
//            try container.encode(listOfIllustrations, forKey: .listOfIllustrations)
//        }
//        if !listOfTables.isEmpty {
//            try container.encode(listOfTables, forKey: .listOfTables)
//        }
//        try container.encode(metadata, forKey: .metadata)
//        if !pageList.isEmpty {
//            try container.encode(pageList, forKey: .pageList)
//        }
//        if !resources.isEmpty {
//            try container.encode(resources, forKey: .resources)
//        }
//        if !readingOrder.isEmpty {
//          try container.encode(readingOrder, forKey: .readingOrder)
//        }
//        if !tableOfContents.isEmpty {
//            try container.encode(tableOfContents, forKey: .tableOfContents)
//        }
    }

}

/// List of strings that can identify a user setting
public enum ReadiumCSSReference: String {
    case fontSize           = "fontSize"
    case fontFamily         = "fontFamily"
    case fontOverride       = "fontOverride"
    case appearance         = "appearance"
    case scroll             = "scroll"
    case publisherDefault   = "advancedSettings"
    case textAlignment      = "textAlign"
    case columnCount        = "colCount"
    case wordSpacing        = "wordSpacing"
    case letterSpacing      = "letterSpacing"
    case pageMargins        = "pageMargins"
    case lineHeight         = "lineHeight"
    case paraIndent         = "paraIndent"
    case hyphens            = "bodyHyphens"
    case ligatures          = "ligatures"
}

/// List of strings that can identify the name of a CSS custom property
/// Also used for storing UserSettings in UserDefaults
public enum ReadiumCSSName: String {
    case fontSize           = "--USER__fontSize"
    case fontFamily         = "--USER__fontFamily"
    case fontOverride       = "--USER__fontOverride"
    case appearance         = "--USER__appearance"
    case scroll             = "--USER__scroll"
    case publisherDefault   = "--USER__advancedSettings"
    case textAlignment      = "--USER__textAlign"
    case columnCount        = "--USER__colCount"
    case wordSpacing        = "--USER__wordSpacing"
    case letterSpacing      = "--USER__letterSpacing"
    case pageMargins        = "--USER__pageMargins"
    case lineHeight         = "--USER__lineHeight"
    case paraIndent         = "--USER__paraIndent"
    case hyphens            = "--USER__bodyHyphens"
    case ligatures          = "--USER__ligatures"
}

// MARK: - Parsing related errors
public enum PublicationError: Error {
    case invalidPublication
    
    var localizedDescription: String {
        switch self {
        case .invalidPublication:
            return "Invalid publication"
        }
    }
}

// MARK: - Parsing related methods
extension Publication {
    
    static public func parse(pubDict: [String: Any]) throws -> Publication {
        let p = Publication()
        for (k, v) in pubDict {
            switch k {
            case "metadata":
                guard let metadataDict = v as? [String: Any] else {
                    throw PublicationError.invalidPublication
                }
                let metadata = try Metadata.parse(metadataDict: metadataDict)
                p.metadata = metadata
            case "links":
                guard let links = v as? [[String: Any]] else {
                    throw PublicationError.invalidPublication
                }
                for linkDict in links {
                    let link = try Link.parse(linkDict: linkDict)
                    p.links.append(link)
                }
            case "images":
                guard let links = v as? [[String: Any]] else {
                    throw PublicationError.invalidPublication
                }
                for linkDict in links {
                    let link = try Link.parse(linkDict: linkDict)
                    p.images.append(link)
                }
            default:
                continue
            }
        }
        return p
    }
    
}
