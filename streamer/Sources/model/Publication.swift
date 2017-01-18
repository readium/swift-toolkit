//
//  Publication.swift
//  R2Streamer
//
//  Created by Olivier Körner on 08/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation
import ObjectMapper


/**
 The representation of EPUB publication, with its metadata, its spine and other resources.

 It is created by the `EpubParser` from an EPUB file or directory.
 As it is extended by `Mappable`, it can be deserialized to `JSON`.
*/
open class Publication: Mappable {
    
    /// The metadata (title, identifier, contributors, etc.)
    public var metadata: Metadata = Metadata()
    
    public var links: [Link] = [Link]()
    
    /// The spine of the publication
    public var spine: [Link] = [Link]()
    
    /// The resources, not including the links already present in the spine
    public var resources: [Link] = [Link]()
    
    /// The table of contents
    public var TOC: [Link] = [Link]()
    public var pageList: [Link] = [Link]()
    public var landmarks: [Link] = [Link]()
    public var LOI: [Link] = [Link]()
    public var LOA: [Link] = [Link]()
    public var LOV: [Link] = [Link]()
    public var LOT: [Link] = [Link]()
    
    public var internalData: [String: String] = [String: String]()

    public var otherLinks: [Link] = [Link]()
    // TODO: other collections
    //var otherCollections: [PublicationCollection]

    /**
     A link to the publication's cover.

     The implementation scans the `links` for a link where `rel` is `cover`.
     If none is found, it is `nil`.
    */
    public var coverLink: Link? {
        get {
            return link(withRel: "cover")
        }
    }
    
    public init() {
    }
    
    /// Mappable JSON protocol initializer
    required public init?(map: Map) {
        // TODO
    }
    
    /**
     Finds a resource (asset or spine item) with a matching relative path
 
     - parameter path: The relative path to match
     - returns: a link with its `href` equal to the path if any was found, else `nil`
    */
    open func resource(withRelativePath path: String) -> Link? {
        let matchingLinks = (spine + resources).filter { $0.href == path }
        if matchingLinks.count > 0 {
            return matchingLinks.first!
        }
        return nil
    }
    
    /**
     Finds the first link with a specific rel
 
     - parameter rel: The `rel` to match
     - returns: The first link with a matching `rel` found uf any, else nil
    */
    open func link(withRel rel: String) -> Link? {
        let matchingLinks = links.filter { (link: Link) -> Bool in
            let coverRel = link.rel.filter { $0 == rel }
            return coverRel.count > 0
        }
        if matchingLinks.count > 0 {
            return matchingLinks.first
        }
        return nil
    }
    
    /// Mapping declaration
    open func mapping(map: Map) {
        metadata <- map["metadata"]
        spine <- map["spine"]
        resources <- map["resources"]
        links <- map["links"]
    }
}


open class Metadata: Mappable {
    
    /// The title of the publication
    public var title: String?
    
    /// The unique identifier
    public var identifier: String?
    
    // Authors, translators and other contributors
    public var authors: [Contributor] = [Contributor]()
    public var translators: [Contributor] = [Contributor]()
    public var editors: [Contributor] = [Contributor]()
    public var artists: [Contributor] = [Contributor]()
    public var illustrators: [Contributor] = [Contributor]()
    public var letterers: [Contributor] = [Contributor]()
    public var pencilers: [Contributor] = [Contributor]()
    public var colorists: [Contributor] = [Contributor]()
    public var inkers: [Contributor] = [Contributor]()
    public var narrators: [Contributor] = [Contributor]()
    public var contributors: [Contributor] = [Contributor]()
    public var publishers: [Contributor] = [Contributor]()
    public var imprints: [Contributor] = [Contributor]()
    
    public var languages: [String] = [String]()
    public var modified: NSDate?
    public var publicationDate: NSDate?
    public var description: String?
    public var direction: String
    public var rendition: Rendition = Rendition()
    public var source: String?
    public var epubType: [String] = [String]()
    public var rights: String?
    public var subjects: [Subject] = [Subject]()

    public var otherMetadata: [MetadataItem] = [MetadataItem]()
    
    public init() {
        direction = "default"
    }
    
    required public init?(map: Map) {
        direction = "default"
        // TODO
    }
    
    open func mapping(map: Map) {
        identifier <- map["identifier"]
        title <- map["title"]
        languages <- map["languages"]
        authors <- map["authors"]
        translators <- map["translators"]
        editors <- map["editors"]
        artists <- map["artists"]
        illustrators <- map["illustrators"]
        letterers <- map["letterers"]
        pencilers <- map["pencilers"]
        colorists <- map["colorists"]
        inkers <- map["inkers"]
        narrators <- map["narrators"]
        contributors <- map["contributors"]
        publishers <- map["publishers"]
        imprints <- map["imprints"]
        modified <- map["modified"]
        publicationDate <- map["publicationDate"]
        rendition <- map["rendition"]
        rights <- map["rights"]
        subjects <- map["subjects"]
    }
}

open class MetadataItem {
    
    public var property: String?
    public var value: String?
    public var children: [MetadataItem] = [MetadataItem]()
    
    public init() {}
}

open class Contributor: Mappable {
    
    public var name: String
    public var sortAs: String?
    public var identifier: String?
    public var role: String?
    
    public init(name: String) {
        self.name = name
    }
    
    public required init?(map: Map) {
        if map.JSON["name"] == nil {
            return nil
        }
        
        name = try! map.value("name")
        sortAs = try? map.value("sortAs")
        identifier = try? map.value("identifier")
        role = try? map.value("role")
    }
    
    open func mapping(map: Map) {
        name <- map["name"]
        sortAs <- map["sortAs"]
        identifier <- map["identifier"]
        role <- map["role"]
    }
}

open class Link: Mappable {
    
    public var href: String?
    public var typeLink: String?
    public var rel: [String] = [String]()
    public var height: Int?
    public var width: Int?
    public var title: String?
    public var properties: [String] = [String]()
    public var duration: TimeInterval?
    public var templated: Bool?
    
    public init() {}
    
    public init(href: String, typeLink: String, rel: String) {
        self.href = href
        self.typeLink = typeLink
        self.rel.append(rel)
    }
    
    public required init?(map: Map) {
        // TODO
    }
    
    open func mapping(map: Map) {
        href <- map["href"]
        typeLink <- map["type"]
        rel <- map["rel"]
        height <- map["height"]
        width <- map["width"]
        duration <- map["duration"]
        title <- map["title"]
    }
}

/**
 The rendition layout property of an EPUB publication

 - Reflowable: not pre-paginated, apply dynamic pagination when rendering
 - Prepaginated: pre-paginated, one page per spine item
*/
public enum RenditionLayout: String {
    case Reflowable = "reflowable"
    case Prepaginated = "pre-paginated"
}

/**
 The rendition flow property of an EPUB publication
 
 - Paginated
 - Continuous
 - Document
 - Fixed
*/
public enum RenditionFlow: String {
    case Paginated = "paginated"
    case Continuous = "continuous"
    case Document = "document"
    case Fixed = "fixed"
}

/**
 The rendition orientation property of an EPUB publication
 
 - Auto
 - Landscape
 - Portrait
*/
public enum RenditionOrientation: String {
    case Auto = "auto"
    case Landscape = "landscape"
    case Portrait = "portrait"
}

/**
 The rendition spread property of an EPUB publication
 
 - Auto
 - Landscape
 - Portrait
 - Both
 - None
*/
public enum RenditionSpread: String {
    case Auto = "auto"
    case Landscape = "landscape"
    case Portrait = "portrait"
    case Both = "both"
    case None = "none"
}

/**
 The information relative to the rendering of the publication.
 
 It includes if it's reflowable or pre-paginated, the orientation, the synthetic spread
 behaviour and if the content flow should be scrolled, continuous or paginated.
 
*/
open class Rendition: Mappable {
    
    /// The rendition layout (reflowable or pre-paginated)
    public var layout: RenditionLayout?
    
    /// The rendition flow
    public var flow: RenditionFlow?
    
    /// The rendition orientation
    public var orientation: RenditionOrientation?
    
    /// The synthetic spread behaviour
    public var spread: RenditionSpread?
    
    /// The rendering viewport size
    public var viewport: String?
    
    public init() {}
    
    required public init?(map: Map) {
        // TODO
    }
    
    open func mapping(map: Map) {
        layout <- map["layout"]
        flow <- map["flow"]
        orientation <- map["orientation"]
        spread <- map["spread"]
        viewport <- map["viewport"]
    }
}

open class Subject: Mappable {
    
    public var name: String?
    public var sortAs: String?
    public var scheme: String?
    public var code: String?
    
    public init() {}
    
    required public init?(map: Map) {
        // TODO
    }
    
    open func mapping(map: Map) {
        name <- map["name"]
        sortAs <- map["sortAs"]
        scheme <- map["scheme"]
        code <- map["code"]
    }
}

