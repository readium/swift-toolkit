//
//  Metadata.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/16/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

/// <#Description#>
open class Metadata: Mappable {

    /// The title of the publication
    public var title: String?

    /// The unique identifier
    public var identifier: String?

    // Authors, translators and other contributors
    public var authors = [Contributor]()
    public var translators = [Contributor]()
    public var editors = [Contributor]()
    public var artists = [Contributor]()
    public var illustrators = [Contributor]()
    public var letterers = [Contributor]()
    public var pencilers = [Contributor]()
    public var colorists = [Contributor]()
    public var inkers = [Contributor]()
    public var narrators = [Contributor]()
    public var contributors = [Contributor]()
    public var publishers = [Contributor]()
    public var imprints = [Contributor]()
    // -
    public var languages = [String]()
    public var modified: NSDate?
    public var publicationDate: NSDate?
    public var description: String?
    public var direction: String
    public var rendition = Rendition()
    public var source: String?
    public var epubType = [String]()
    public var rights: String?
    public var subjects = [Subject]()
    // -
    public var otherMetadata = [MetadataItem]()

    public init() {
        direction = "default"
    }

    required public init?(map: Map) {
        direction = "default"
        // TODO: init
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
