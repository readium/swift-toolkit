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
    public var version: Double!
    /// The metadata (title, identifier, contributors, etc.).
    public var metadata: Metadata!
    public var links = [Link]()
    public var spine = [Link]()
    /// The resources, not including the links already present in the spine.
    public var resources = [Link]()
    /// TOC
    public var tableOfContents = [Link]()
    public var landmarks = [Link]()
    public var listOfAudioFiles = [Link]()
    public var listOfIllustrations = [Link]()
    public var listOfTables = [Link]()
    public var listOfVideos = [Link]()
    public var pageList = [Link]()

    /// Extension point for links that shouldn't show up in the manifest
    public var otherLinks = [Link]()
    // TODO: other collections
    // var otherCollections: [PublicationCollection]
    public var internalData = [String: String]()

    // MARK: - Public methods.

    /// A link to the publication's cover.
    /// The implementation scans the `links` for a link where `rel` is `cover`.
    /// If none is found, it is `nil`.
    public var coverLink: Link? {
        get {
            return link(withRel: "cover")
        }
    }

    /// Return the serialized JSON for the Publication object: the WebPubManifest
    /// (canonical).
    public var manifest: String {
        var jsonString = self.toJSONString(prettyPrint: false) ?? ""

        jsonString = jsonString.replacingOccurrences(of: "\\", with: "")
        return jsonString
    }

    /// Return the serialized JSON for the Publication object: the WebPubManifest
    /// (prettyfied).
    public var manifestPretty: String {
        var jsonString = self.toJSONString(prettyPrint: true) ?? ""

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
    required public init?(map: Map) {}

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


    // Mark: - Internal Methods.

    /// Append the self/manifest link to  links.
    ///
    /// - Parameters:
    ///   - endPoint: The URI prefix to use to fetch assets from the publication.
    ///   - baseUrl: The base URL of the HTTP server.
    internal func addSelfLink(endpoint: String, for baseUrl: URL) {
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
