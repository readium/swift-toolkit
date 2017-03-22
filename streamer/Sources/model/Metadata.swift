//
//  Metadata.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/16/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

/// The data representation of the <metadata> element of the "*.opf" file.
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

    public var modified: Date?
    public var publicationDate: Date?
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
        var modifiedDate = modified?.iso8601
        var pubDate = publicationDate?.iso8601

        identifier <- map["identifier", ignoreNil: true]
        title <- map["title", ignoreNil: true]
        languages <- map["languages", ignoreNil: true]
        if !authors.isEmpty {
            authors <- map["authors", ignoreNil: true]
        }
        if !translators.isEmpty {
            translators <- map["translators", ignoreNil: true]
        }
        if !editors.isEmpty {
            editors <- map["editors", ignoreNil: true]
        }
        if !artists.isEmpty {
            artists <- map["artists", ignoreNil: true]
        }
        if !illustrators.isEmpty {
            illustrators <- map["illustrators", ignoreNil: true]
        }
        if !letterers.isEmpty {
            letterers <- map["letterers", ignoreNil: true]
        }
        if !pencilers.isEmpty {
            pencilers <- map["pencilers", ignoreNil: true]
        }
        if !colorists.isEmpty {
            colorists <- map["colorists", ignoreNil: true]
        }
        if !inkers.isEmpty {
            inkers <- map["inkers", ignoreNil: true]
        }
        if !narrators.isEmpty {
            narrators <- map["narrators", ignoreNil: true]
        }
        if !contributors.isEmpty {
            contributors <- map["contributors", ignoreNil: true]
        }
        if !publishers.isEmpty {
            publishers <- map["publishers", ignoreNil: true]
        }
        if !imprints.isEmpty {
            imprints <- map["imprints", ignoreNil: true]
        }
        modifiedDate <- map["modified", ignoreNil: true]
        pubDate <- map["publicationDate", ignoreNil: true]
        rendition <- map["rendition", ignoreNil: true]
        source <- map["source", ignoreNil: true]
        rights <- map["rights", ignoreNil: true]
        if !subjects.isEmpty {
            subjects <- map["subjects", ignoreNil: true]
        }
    }
}
