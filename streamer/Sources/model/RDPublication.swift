//
//  RDPublication.swift
//  R2Streamer
//
//  Created by Olivier Körner on 08/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation
import ObjectMapper


/**
 The representation of EPUB publication, with its metadata, its spine and other resources.

 It is created by the `RDEpubParser` from an EPUB file or directory.
 As it is extended by `Mappable`, it can be deserialized to `JSON`.
*/
open class RDPublication: Mappable {
    
    /// The metadata (title, identifier, contributors, etc.)
    public var metadata: RDMetadata = RDMetadata()
    
    public var links: [RDLink] = [RDLink]()
    
    /// The spine of the publication
    public var spine: [RDLink] = [RDLink]()
    
    /// The resources, not including the links already present in the spine
    public var resources: [RDLink] = [RDLink]()
    
    /// The table of contents
    public var TOC: [RDLink] = [RDLink]()
    public var pageList: [RDLink] = [RDLink]()
    public var landmarks: [RDLink] = [RDLink]()
    public var LOI: [RDLink] = [RDLink]()
    public var LOA: [RDLink] = [RDLink]()
    public var LOV: [RDLink] = [RDLink]()
    public var LOT: [RDLink] = [RDLink]()
    
    public var internalData: [String: String] = [String: String]()

    public var otherLinks: [RDLink] = [RDLink]()
    // TODO: other collections
    //var otherCollections: [RDPublicationCollection]

    /**
     A link to the publication's cover.

     The implementation scans the `links` for a link where `rel` is `cover`.
     If none is found, it is `nil`.
    */
    public var coverLink: RDLink? {
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
    open func resource(withRelativePath path: String) -> RDLink? {
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
    open func link(withRel rel: String) -> RDLink? {
        let matchingLinks = links.filter { (link: RDLink) -> Bool in
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


open class RDMetadata: Mappable {
    
    /// The title of the publication
    public var title: String?
    
    /// The unique identifier
    public var identifier: String?
    
    // Authors, translators and other contributors
    public var authors: [RDContributor] = [RDContributor]()
    public var translators: [RDContributor] = [RDContributor]()
    public var editors: [RDContributor] = [RDContributor]()
    public var artists: [RDContributor] = [RDContributor]()
    public var illustrators: [RDContributor] = [RDContributor]()
    public var letterers: [RDContributor] = [RDContributor]()
    public var pencilers: [RDContributor] = [RDContributor]()
    public var colorists: [RDContributor] = [RDContributor]()
    public var inkers: [RDContributor] = [RDContributor]()
    public var narrators: [RDContributor] = [RDContributor]()
    public var contributors: [RDContributor] = [RDContributor]()
    public var publishers: [RDContributor] = [RDContributor]()
    public var imprints: [RDContributor] = [RDContributor]()
    
    public var languages: [String] = [String]()
    public var modified: NSDate?
    public var publicationDate: NSDate?
    public var description: String?
    public var direction: String
    public var rendition: RDRendition = RDRendition()
    public var source: String?
    public var epubType: [String] = [String]()
    public var rights: String?
    public var subjects: [RDSubject] = [RDSubject]()

    public var otherMetadata: [RDMetadataItem] = [RDMetadataItem]()
    
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

open class RDMetadataItem {
    
    public var property: String?
    public var value: String?
    public var children: [RDMetadataItem] = [RDMetadataItem]()
    
    public init() {}
}

open class RDContributor: Mappable {
    
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

open class RDLink: Mappable {
    
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
public enum RDRenditionLayout: String {
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
public enum RDRenditionFlow: String {
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
public enum RDRenditionOrientation: String {
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
public enum RDRenditionSpread: String {
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
open class RDRendition: Mappable {
    
    /// The rendition layout (reflowable or pre-paginated)
    public var layout: RDRenditionLayout?
    
    /// The rendition flow
    public var flow: RDRenditionFlow?
    
    /// The rendition orientation
    public var orientation: RDRenditionOrientation?
    
    /// The synthetic spread behaviour
    public var spread: RDRenditionSpread?
    
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

open class RDSubject: Mappable {
    
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

