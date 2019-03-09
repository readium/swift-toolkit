//
//  WPMetadata.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


public enum WPReadingProgression: String {
    case rtl, ltr, auto
}


/// https://readium.org/webpub-manifest/schema/metadata.schema.json
public struct WPMetadata: Equatable {

    public var identifier: String?  // URI
    public var type: String?  // URI (@type)
    public var title: WPLocalizedString
    public var subtitle: WPLocalizedString?
    public var modified: Date?
    public var published: Date?
    public var languages: [String]  // BCP 47 tag
    public var sortAs: String?
    public var authors: [WPContributor]
    public var translators: [WPContributor]
    public var editors: [WPContributor]
    public var artists: [WPContributor]
    public var illustrators: [WPContributor]
    public var letterers: [WPContributor]
    public var pencilers: [WPContributor]
    public var colorists: [WPContributor]
    public var inkers: [WPContributor]
    public var narrators: [WPContributor]
    public var contributors: [WPContributor]
    public var publishers: [WPContributor]
    public var imprints: [WPContributor]
    public var readingProgression: WPReadingProgression
    public var description: String?
    public var duration: Double?
    public var numberOfPages: Int?
    public var belongsTo: BelongsTo?

    // MARK: - EPUB Extension
    
    public var rendition: WPRendition?

    public init(identifier: String? = nil, type: String? = nil, title: WPLocalizedString, subtitle: WPLocalizedString? = nil, modified: Date? = nil, published: Date? = nil, languages: [String] = [], sortAs: String? = nil, authors: [WPContributor] = [], translators: [WPContributor] = [], editors: [WPContributor] = [], artists: [WPContributor] = [], illustrators: [WPContributor] = [], letterers: [WPContributor] = [], pencilers: [WPContributor] = [], colorists: [WPContributor] = [], inkers: [WPContributor] = [], narrators: [WPContributor] = [], contributors: [WPContributor] = [], publishers: [WPContributor] = [], imprints: [WPContributor] = [], readingProgression: WPReadingProgression = .auto, description: String? = nil, duration: Double? = nil, numberOfPages: Int? = nil, belongsTo: BelongsTo? = nil, rendition: WPRendition? = nil) {
        self.identifier = identifier
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.modified = modified
        self.published = published
        self.languages = languages
        self.sortAs = sortAs
        self.authors = authors
        self.translators = translators
        self.editors = editors
        self.artists = artists
        self.illustrators = illustrators
        self.letterers = letterers
        self.pencilers = pencilers
        self.colorists = colorists
        self.inkers = inkers
        self.narrators = narrators
        self.contributors = contributors
        self.publishers = publishers
        self.imprints = imprints
        self.readingProgression = readingProgression
        self.description = description
        self.duration = duration
        self.numberOfPages = numberOfPages
        self.belongsTo = belongsTo
        self.rendition = rendition
    }
    
    init(json: Any) throws {
        guard let json = json as? [String: Any],
            let title = try WPLocalizedString(json: json["title"]) else
        {
            throw WPParsingError.metadata
        }
        
        self.identifier = json["identifier"] as? String
        self.type = json["@type"] as? String
        self.title = title
        self.subtitle = try WPLocalizedString(json: json["subtitle"])
        self.modified = parseDate(json["modified"])
        self.published = parseDate(json["published"])
        self.languages = parseArray(json["language"], allowingSingle: true)
        self.sortAs = json["sortAs"] as? String
        self.authors = try .init(json: json["author"])
        self.translators = try .init(json: json["translator"])
        self.editors = try .init(json: json["editor"])
        self.artists = try .init(json: json["artist"])
        self.illustrators = try .init(json: json["illustrator"])
        self.letterers = try .init(json: json["letterer"])
        self.pencilers = try .init(json: json["penciler"])
        self.colorists = try .init(json: json["colorist"])
        self.inkers = try .init(json: json["inker"])
        self.narrators = try .init(json: json["narrator"])
        self.contributors = try .init(json: json["contributor"])
        self.publishers = try .init(json: json["publisher"])
        self.imprints = try .init(json: json["imprint"])
        self.readingProgression = parseRaw(json["readingProgression"]) ?? .auto
        self.description = json["description"] as? String
        self.duration = parsePositiveDouble(json["duration"])
        self.numberOfPages = parsePositive(json["numberOfPages"])
        self.belongsTo = try BelongsTo(json: json["belongsTo"])
        self.rendition = try WPRendition(json: json["rendition"])
    }
    
    var json: [String: Any] {
        return makeJSON([
            "identifier": encodeIfNotNil(identifier),
            "@type": encodeIfNotNil(type),
            "title": title.json,
            "subtitle": encodeIfNotNil(subtitle?.json),
            "modified": encodeIfNotNil(modified?.iso8601),
            "published": encodeIfNotNil(published?.iso8601),
            "language": encodeIfNotEmpty(languages),
            "sortAs": encodeIfNotNil(sortAs),
            "author": encodeIfNotEmpty(authors.json),
            "translator": encodeIfNotEmpty(translators.json),
            "editor": encodeIfNotEmpty(editors.json),
            "artist": encodeIfNotEmpty(artists.json),
            "illustrator": encodeIfNotEmpty(illustrators.json),
            "letterer": encodeIfNotEmpty(letterers.json),
            "penciler": encodeIfNotEmpty(pencilers.json),
            "colorist": encodeIfNotEmpty(colorists.json),
            "inker": encodeIfNotEmpty(inkers.json),
            "narrator": encodeIfNotEmpty(narrators.json),
            "contributor": encodeIfNotEmpty(contributors.json),
            "publisher": encodeIfNotEmpty(publishers.json),
            "imprint": encodeIfNotEmpty(imprints.json),
            "readingProgression": readingProgression.rawValue,
            "description": encodeIfNotNil(description),
            "duration": encodeIfNotNil(duration),
            "numberOfPages": encodeIfNotNil(numberOfPages),
            "belongsTo": encodeIfNotNil(belongsTo?.json),
            "rendition": encodeIfNotNil(rendition?.json)
        ])
    }

    public struct BelongsTo: Equatable {
        public var collections: [WPContributor]
        public var series: [WPContributor]
        
        init(collections: [WPContributor] = [], series: [WPContributor] = []) {
            self.collections = collections
            self.series = series
        }
        
        init?(json: Any?) throws {
            if json == nil {
                return nil
            }
            guard let json = json as? [String: Any] else {
                throw WPParsingError.belongsTo
            }
            collections = try .init(json: json["collection"])
            series = try .init(json: json["series"])
        }
        
        var json: [String: Any]? {
            let json = makeJSON([
                "collection": encodeIfNotEmpty(collections.json),
                "series": encodeIfNotEmpty(series.json)
            ])
            // Nil if empty to not include in the parent structure.
            return json.isEmpty ? nil : json
        }
        
    }
    
}
