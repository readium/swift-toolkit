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
open class Publication: Mappable {

    /// The metadata (title, identifier, contributors, etc.).
    public var metadata = Metadata()
    public var links = [Link]()

    /// The spine of the publication.
    public var spine = [Link]()

    /// The resources, not including the links already present in the spine.
    public var resources = [Link]()

    /// The table of contents.
    public var TOC = [Link]()
    public var pageList = [Link]()
    public var landmarks = [Link]()
    // FIXME: Epub spec / rename to explicit full names
    public var LOI = [Link]()
    public var LOA = [Link]()
    public var LOV = [Link]()
    public var LOT = [Link]()
    public var internalData = [String: String]()
    public var otherLinks = [Link]()

    // TODO: other collections
    // var otherCollections: [PublicationCollection]

    // MARK: - Public methods.

    /// A link to the publication's cover.
    /// The implementation scans the `links` for a link where `rel` is `cover`.
    /// If none is found, it is `nil`.
    public var coverLink: Link? {
        get { return link(withRel: "cover") }
    }

    public init() {
    }
    
    /// Mappable JSON protocol initializer
    required public init?(map: Map) {
        // TODO: init
    }

    // MARK: - Open methods.

    /// Finds a resource (asset or spine item) with a matching relative path
    ///
    /// - Parameter path: The relative path to match
    /// - Returns: a link with its `href` equal to the path if any was found,
    ///            else `nil`
    open func resource(withRelativePath path: String) -> Link? {
        let matchingLinks = (spine + resources).filter { $0.href == path }

        if !matchingLinks.isEmpty {
            return matchingLinks.first
        }
        return nil
    }

    /// Finds the first link with a specific rel
    ///
    /// - Parameter rel: The `rel` to match
    /// - Returns: The first link with a matching `rel` found uf any, else nil
    open func link(withRel rel: String) -> Link? {
        let matchingLinks = links.filter { (link: Link) -> Bool in
            let coverRel = link.rel.filter { $0 == rel }

            return !coverRel.isEmpty
        }
        if !matchingLinks.isEmpty {
            return matchingLinks.first
        }
        return nil
    }
    
    /// Mapping declaration
    open func mapping(map: Map) {
        metadata <- map["metadata"]//, ignoreNil: true]
        spine <- map["spine"]
        resources <- map["resources"]
        links <- map["links"]
    }
}
