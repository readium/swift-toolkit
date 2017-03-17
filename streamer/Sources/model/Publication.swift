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
public class Publication: Mappable {
    
    /// The epubVersion of the publication
    public var epubVersion = 0.0
    /// The metadata (title, identifier, contributors, etc.).
    public var metadata = Metadata()
    public var links = [Link]()
    public var spine = [Link]()
    /// The resources, not including the links already present in the spine.
    public var resources = [Link]()
    /// <=> TOC, pageList, landmarks && <=> LOI, LOT | (LOA, LOV [?])
    public var tableOfContents = [Link]()
    public var pageList = [Link]()
    public var landmarks = [Link]()
    public var listOfIllustrations = [Link]()
    public var listOfTables = [Link]()
    // FIXME: commented because not even on the ipdf documentation page?
    //    public var listOfAudioFiles = [Link]()
    //    public var listOfVideos = [Link]()

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

    public init() {
    }
    
    /// Mappable JSON protocol initializer
    required public init?(map: Map) {
        // TODO: init
    }

    // MARK: - Public methods.

    /// Finds a resource (asset or spine item) with a matching relative path
    ///
    /// - Parameter path: The relative path to match
    /// - Returns: a link with its `href` equal to the path if any was found,
    ///            else `nil`
    public func resource(withRelativePath path: String) -> Link? {
        let matchingLinks = (spine + resources)

        return matchingLinks.first(where: { $0.href == path })
    }

    /// Find the first Link having the given `rel` in the publication [Link]
    /// properties: `resources`, `spine`, `links`.
    ///
    /// - Parameter rel: The `rel` being searched.
    /// - Returns: The corresponding `Link`, if any.
    public func link(withRel rel: String) -> Link? {
        if let link = resources.first(where: { $0.rel.contains(rel) }) {
            return link
        }
        if let link = spine.first(where: { $0.rel.contains(rel) }) {
            return link
        }
        if let link = links.first(where: { $0.rel.contains(rel) }) {
            return link
        }
        return nil
    }
    
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
