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

    public var title: String?
    public var languages = [String]()
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
    public var imprints = [Contributor]()
    //
    public var subjects = [Subject]()
    public var publishers = [Contributor]()
    public var contributors = [Contributor]()

    public var modified: NSDate?
    public var publicationDate: NSDate?
    public var description: String?
    public var direction: String
    public var rendition = Rendition()
    public var source: String?
    public var epubType = [String]()
    public var rights: String?

    public var otherMetadata = [MetadataItem]()

    // MARK: - Public methods.

    public init() {
        direction = "default"
    }

    required public init?(map: Map) {
        direction = "default"
        // TODO: init
    }

    // MARK: - Open methods

    open func mapping(map: Map) {
        identifier <- map["identifier", ignoreNil: true]
        title <- map["title", ignoreNil: true]
        languages <- map["languages", ignoreNil: true]
        authors <- map["authors", ignoreNil: true]
        translators <- map["translators", ignoreNil: true]
        editors <- map["editors", ignoreNil: true]
        artists <- map["artists", ignoreNil: true]
        illustrators <- map["illustrators", ignoreNil: true]
        letterers <- map["letterers", ignoreNil: true]
        pencilers <- map["pencilers", ignoreNil: true]
        colorists <- map["colorists", ignoreNil: true]
        inkers <- map["inkers", ignoreNil: true]
        narrators <- map["narrators", ignoreNil: true]
        contributors <- map["contributors", ignoreNil: true]
        publishers <- map["publishers", ignoreNil: true]
        imprints <- map["imprints", ignoreNil: true]
        modified <- map["modified", ignoreNil: true]
        publicationDate <- map["publicationDate", ignoreNil: true]
        rendition <- map["rendition", ignoreNil: true]
        rights <- map["rights", ignoreNil: true]
        subjects <- map["subjects", ignoreNil: true]
    }
}
