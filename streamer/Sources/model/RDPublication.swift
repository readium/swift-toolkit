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
class RDPublication: Mappable {
    
    /// The metadata (title, identifier, contributors, etc.)
    var metadata: RDMetadata = RDMetadata()
    
    var links: [RDLink] = [RDLink]()
    
    /// The spine of the publication
    var spine: [RDLink] = [RDLink]()
    
    /// The resources, not including the links already present in the spine
    var resources: [RDLink] = [RDLink]()
    
    /// The table of contents
    var TOC: [RDLink] = [RDLink]()
    var pageList: [RDLink] = [RDLink]()
    var landmarks: [RDLink] = [RDLink]()
    var LOI: [RDLink] = [RDLink]()
    var LOA: [RDLink] = [RDLink]()
    var LOV: [RDLink] = [RDLink]()
    var LOT: [RDLink] = [RDLink]()
    
    var internalData: [String: String] = [String: String]()

    var otherLinks: [RDLink] = [RDLink]()
    // TODO: other collections
    //var otherCollections: [RDPublicationCollection]

    /**
     A link to the publication's cover.

     The implementation scans the `links` for a link where `rel` is `cover`.
     If none is found, it is `nil`.
    */
    var coverLink: RDLink? {
        get {
            return link(withRel: "cover")
        }
    }
    
    init() {
    }
    
    /// Mappable JSON protocol initializer
    required init?(map: Map) {
        // TODO
    }
    
    /**
     Finds a resource (asset or spine item) with a matching relative path
 
     - parameter path: The relative path to match
     - returns: a link with its `href` equal to the path if any was found, else `nil`
    */
    func resource(withRelativePath path: String) -> RDLink? {
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
    func link(withRel rel: String) -> RDLink? {
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
    func mapping(map: Map) {
        metadata <- map["metadata"]
        spine <- map["spine"]
        resources <- map["resources"]
        links <- map["links"]
    }
}


class RDMetadata: Mappable {
    
    /// The title of the publication
    var title: String?
    
    /// The unique identifier
    var identifier: String?
    
    // Authors, translators and other contributors
    var authors: [RDContributor] = [RDContributor]()
    var translators: [RDContributor] = [RDContributor]()
    var editors: [RDContributor] = [RDContributor]()
    var artists: [RDContributor] = [RDContributor]()
    var illustrators: [RDContributor] = [RDContributor]()
    var letterers: [RDContributor] = [RDContributor]()
    var pencilers: [RDContributor] = [RDContributor]()
    var colorists: [RDContributor] = [RDContributor]()
    var inkers: [RDContributor] = [RDContributor]()
    var narrators: [RDContributor] = [RDContributor]()
    var contributors: [RDContributor] = [RDContributor]()
    var publishers: [RDContributor] = [RDContributor]()
    var imprints: [RDContributor] = [RDContributor]()
    
    var languages: [String] = [String]()
    var modified: NSDate?
    var publicationDate: NSDate?
    var description: String?
    var direction: String
    var rendition: RDRendition = RDRendition()
    var source: String?
    var epubType: [String] = [String]()
    var rights: String?
    var subjects: [RDSubject] = [RDSubject]()

    var otherMetadata: [RDMetadataItem] = [RDMetadataItem]()
    
    init() {
        direction = "default"
    }
    
    required init?(map: Map) {
        direction = "default"
        // TODO
    }
    
    func mapping(map: Map) {
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

class RDMetadataItem {
    
    var property: String?
    var value: String?
    var children: [RDMetadataItem] = [RDMetadataItem]()
    
    init() {}
}

class RDContributor: Mappable {
    
    var name: String
    var sortAs: String?
    var identifier: String?
    var role: String?
    
    init(name: String) {
        self.name = name
    }
    
    required init?(map: Map) {
        if map.JSON["name"] == nil {
            return nil
        }
        
        name = try! map.value("name")
        sortAs = try? map.value("sortAs")
        identifier = try? map.value("identifier")
        role = try? map.value("role")
    }
    
    func mapping(map: Map) {
        name <- map["name"]
        sortAs <- map["sortAs"]
        identifier <- map["identifier"]
        role <- map["role"]
    }
}

class RDLink: Mappable {
    
    var href: String?
    var typeLink: String?
    var rel: [String] = [String]()
    var height: Int?
    var width: Int?
    var title: String?
    var properties: [String] = [String]()
    var duration: TimeInterval?
    var templated: Bool?
    
    init() {}
    
    init(href: String, typeLink: String, rel: String) {
        self.href = href
        self.typeLink = typeLink
        self.rel.append(rel)
    }
    
    required init?(map: Map) {
        // TODO
    }
    
    func mapping(map: Map) {
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
enum RDRenditionLayout: String {
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
enum RDRenditionFlow: String {
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
enum RDRenditionOrientation: String {
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
enum RDRenditionSpread: String {
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
class RDRendition: Mappable {
    
    /// The rendition layout (reflowable or pre-paginated)
    var layout: RDRenditionLayout?
    
    /// The rendition flow
    var flow: RDRenditionFlow?
    
    /// The rendition orientation
    var orientation: RDRenditionOrientation?
    
    /// The synthetic spread behaviour
    var spread: RDRenditionSpread?
    
    /// The rendering viewport size
    var viewport: String?
    
    init() {}
    
    required init?(map: Map) {
        // TODO
    }
    
    func mapping(map: Map) {
        layout <- map["layout"]
        flow <- map["flow"]
        orientation <- map["orientation"]
        spread <- map["spread"]
        viewport <- map["viewport"]
    }
}

class RDSubject: Mappable {
    var name: String?
    var sortAs: String?
    var scheme: String?
    var code: String?
    
    init() {}
    
    required init?(map: Map) {
        // TODO
    }
    
    func mapping(map: Map) {
        name <- map["name"]
        sortAs <- map["sortAs"]
        scheme <- map["scheme"]
        code <- map["code"]
    }
}

