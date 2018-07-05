//
//  Publication.swift
//  R2Streamer
//
//  Created by Olivier Körner on 08/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

/// The representation of EPUB publication, with its metadata, its spine and 
/// other resources.
/// It is created by the `EpubParser` from an EPUB file or directory.
/// As it is extended by `Mappable`, it can be deserialized to `JSON`.
public class Publication {
    /// The version of the publication, if the type needs any.
    public var version: Double
    /// The metadata (title, identifier, contributors, etc.).
    public var metadata: Metadata
    /// Link to special ressources which are added to the publication.
    public var links = [Link]()
    /// Links of the spine items of the publication.
    public var spine = [Link]()
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
    
    /// The updated date of file which is referenced by this Publication
    public var updatedDate:Date = Date() // default value to avoid optional chain

    /// Extension point for links that shouldn't show up in the manifest.
    public var otherLinks = [Link]()
    // TODO: other collections
    // var otherCollections: [PublicationCollection]
    public var internalData = [String: String]()
    
    // The status of Settings prpperties. Enable or disable
    public var userSettingsUIPreset:[ReadiumCSSKey:Bool]?

    // MARK: - Public methods.

    /// A link to the publication's cover.
    /// The implementation scans the `links` for a link (spine/resources/links) where `rel` is `cover`.
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
        guard let selfLinkHref = selfLink.href,
            var pubBaseUrl = URL(string: selfLinkHref)?.deletingLastPathComponent() else
        {
            print("Error: invalid publication self link")
            return nil
        }
        return pubBaseUrl
    }()

    /// Return the serialized JSON for the Publication object: the WebPubManifest
    /// (canonical).
    public var manifest: String {
        var jsonString = self.toJSONString(prettyPrint: true) ?? ""

        jsonString = jsonString.replacingOccurrences(of: "\\", with: "")
        return jsonString
    }

    public var manifestCanonical: String {
        // Not needed so far.
        let canonicalPublication = self

        // Remove links.
        canonicalPublication.links = []
        // Ordered. (Looks like it's already done)
        // func linkOrderedAscending(_ l1: Link, _ l2: Link) -> Bool {
        //      return l1.href?.localizedStandardCompare(l2.href!) == ComparisonResult.orderedAscending
        // }
        // orderedPublication.links.sort(by: linkOrderedAscending)
        //  ...
        var jsonString = canonicalPublication.toJSONString(prettyPrint: false) ?? ""

        jsonString = jsonString.replacingOccurrences(of: "\\", with: "")
        return jsonString
        
    }

    /// Returns the JSON dictionnary.
    public var manifestDictionnary: [String: Any] {
        return self.toJSON()
    }

    public init() {
        version = 0.0
        metadata = Metadata()
    }

    /// Mappable JSON protocol initializer
    required public init?(map: Map) {
        version = 0.0
        metadata = Metadata()
    }

    // Mark: - Public methods.

    /// Finds a resource (asset or spine item) with a matching relative path.
    ///
    /// - Parameter path: The relative path to match
    /// - Returns: a link with its `href` equal to the path if any was found,
    ///            else `nil`
    public func resource(withRelativePath path: String) -> Link? {
        let matchingLinks = (spine + resources)

        return matchingLinks.first(where: { $0.href == path })
    }


    /// Return a link from the spine having the given Href.
    ///
    /// - Parameter href: The `href` being searched.
    /// - Returns: The corresponding `Link` if any.
    public func spineLink(withHref href: String) -> Link? {
        return spine.first(where: { $0.href == href })
    }

    /// Find the first Link having the given `rel` in the publications's [Link]
    /// properties: `resources`, `spine`, `links`.
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
    /// properties: `resources`, `spine`, `links`.
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
            let linkHref = link.href,
            let publicationBaseUrl = baseUrl else
        {
            return nil
        }
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
        let link = Link()
        let manifestPath = "\(endpoint)/manifest.json"

        publicationURL = baseUrl.appendingPathComponent(manifestPath, isDirectory: false)
        link.href = publicationURL.absoluteString
        link.typeLink = "application/webpub+json"
        link.rel.append("self")
        links.append(link)
    }

    // Mark: - Fileprivate Methods.
    
    /// Find the first link conforming to the passed closure, using `.where()`
    /// in the publications's [Link] properties: `resources`, `spine`, `links`.
    ///
    /// - Parameter closure: The closure to conform to.
    /// - Returns: The corresponding Link found, if any.
    fileprivate func findLinkInPublicationLinks(where closure: (Link) -> Bool) -> Link? {
        if let link = resources.first(where: closure) {
            return link
        }
        if let link = spine.first(where: closure) {
            return link
        }
        if let link = links.first(where: closure) {
            return link
        }
        return nil
    }
}

extension Publication: Mappable {

    /// Mapping declaration
    public func mapping(map: Map) {
        metadata <- map["metadata", ignoreNil: true]
        if !links.isEmpty {
            links <- map["links", ignoreNil: true]
        }
        if !spine.isEmpty {
            spine <- map["spine", ignoreNil: true]
        }
        if !resources.isEmpty {
            resources <- map["resources", ignoreNil: true]
        }
        if !tableOfContents.isEmpty {
            tableOfContents <- map["toc", ignoreNil: true]
        }
        if !pageList.isEmpty {
            pageList <- map["page-list", ignoreNil: true]
        }
        if !landmarks.isEmpty {
            landmarks <- map["landmarks", ignoreNil: true]
        }
        if !listOfIllustrations.isEmpty {
            listOfIllustrations <- map["loi", ignoreNil: true]
        }
        if !listOfTables.isEmpty {
            listOfTables <- map["lot", ignoreNil: true]
        }
    }
}

// The keys in ReadiumCss. Also used for storing UserSettings in UserDefaults.
public enum ReadiumCSSKey: String {
    case fontSize = "--USER__fontSize"
    case font = "--USER__fontFamily"
    case appearance = "--USER__appearance"
    case scroll = "--USER__scroll"
    case publisherSettings = "--USER__advancedSettings"
    case wordSpacing = "--USER__wordSpacing"
    case letterSpacing = "--USER__letterSpacing"
    case columnCount = "--USER__colCount"
    case pageMargins = "--USER__pageMargins"
    case textAlignement = "--USER__textAlign"
    //--USER__darkenImages --USER__invertImages
    
    case paraIndent = "--USER__paraIndent"
    
    case hyphens = "--USER__bodyHyphens"
    case ligatures = "--USER__ligatures"
    
    case publisherFont = "--USER__fontOverride"
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
