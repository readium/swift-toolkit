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


/// Collection struct used for collection/series metadata.
/// For convenience, the JSON schema reuse the Contributor's definition.
public typealias WPPublicationCollection = WPContributor


public enum WPReadingProgression: String {
    case rtl
    case ltr
    case auto
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
    public var subjects: [WPSubject]
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
    
    public var rendition: Rendition?
    
    
    /// Additional properties for extensions.
    public var otherMetadata: [String: Any] {
        return otherMetadataJSON.json
    }
    // Trick to keep the struct equatable despite [String: Any]
    private var otherMetadataJSON: JSONDictionary
    

    public init(identifier: String? = nil, type: String? = nil, title: WPLocalizedString, subtitle: WPLocalizedString? = nil, modified: Date? = nil, published: Date? = nil, languages: [String] = [], sortAs: String? = nil, subjects: [WPSubject] = [], authors: [WPContributor] = [], translators: [WPContributor] = [], editors: [WPContributor] = [], artists: [WPContributor] = [], illustrators: [WPContributor] = [], letterers: [WPContributor] = [], pencilers: [WPContributor] = [], colorists: [WPContributor] = [], inkers: [WPContributor] = [], narrators: [WPContributor] = [], contributors: [WPContributor] = [], publishers: [WPContributor] = [], imprints: [WPContributor] = [], readingProgression: WPReadingProgression = .auto, description: String? = nil, duration: Double? = nil, numberOfPages: Int? = nil, belongsTo: BelongsTo? = nil, rendition: Rendition? = nil, otherMetadata: [String: Any] = [:]) {
        self.identifier = identifier
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.modified = modified
        self.published = published
        self.languages = languages
        self.sortAs = sortAs
        self.subjects = subjects
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
        self.otherMetadataJSON = JSONDictionary(otherMetadata) ?? JSONDictionary()
    }
    
    init(json: Any?) throws {
        guard var json = JSONDictionary(json),
            let title = try WPLocalizedString(json: json.pop("title")) else
        {
            throw JSONParsingError.metadata
        }
        
        self.identifier = json.pop("identifier") as? String
        self.type = json.pop("@type") as? String ?? json.pop("type") as? String
        self.title = title
        self.subtitle = try WPLocalizedString(json: json.pop("subtitle"))
        self.modified = parseDate(json.pop("modified"))
        self.published = parseDate(json.pop("published"))
        self.languages = parseArray(json.pop("language"), allowingSingle: true)
        self.sortAs = json.pop("sortAs") as? String
        self.subjects = [WPSubject](json: json.pop("subject"))
        self.authors = [WPContributor](json: json.pop("author"))
        self.translators = [WPContributor](json: json.pop("translator"))
        self.editors = [WPContributor](json: json.pop("editor"))
        self.artists = [WPContributor](json: json.pop("artist"))
        self.illustrators = [WPContributor](json: json.pop("illustrator"))
        self.letterers = [WPContributor](json: json.pop("letterer"))
        self.pencilers = [WPContributor](json: json.pop("penciler"))
        self.colorists = [WPContributor](json: json.pop("colorist"))
        self.inkers = [WPContributor](json: json.pop("inker"))
        self.narrators = [WPContributor](json: json.pop("narrator"))
        self.contributors = [WPContributor](json: json.pop("contributor"))
        self.publishers = [WPContributor](json: json.pop("publisher"))
        self.imprints = [WPContributor](json: json.pop("imprint"))
        self.readingProgression = parseRaw(json.pop("readingProgression")) ?? .auto
        self.description = json.pop("description") as? String
        self.duration = parsePositiveDouble(json.pop("duration"))
        self.numberOfPages = parsePositive(json.pop("numberOfPages"))
        self.belongsTo = try BelongsTo(json: json.pop("belongsTo"))
        self.rendition = try Rendition(json: json.pop("rendition"))
        self.otherMetadataJSON = json
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
            "subject": encodeIfNotEmpty(subjects.json),
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
            "belongsTo": encodeIfNotEmpty(belongsTo?.json),
            "rendition": encodeIfNotEmpty(rendition?.json)
        ], additional: otherMetadata)
    }

    public struct BelongsTo: Equatable {
        public var collections: [WPPublicationCollection]
        public var series: [WPPublicationCollection]
        
        init(collections: [WPPublicationCollection] = [], series: [WPPublicationCollection] = []) {
            self.collections = collections
            self.series = series
        }
        
        init?(json: Any?) throws {
            if json == nil {
                return nil
            }
            guard let json = json as? [String: Any] else {
                throw JSONParsingError.metadata
            }
            collections = [WPPublicationCollection](json: json["collection"])
            series = [WPPublicationCollection](json: json["series"])
        }
        
        var json: [String: Any] {
            return makeJSON([
                "collection": encodeIfNotEmpty(collections.json),
                "series": encodeIfNotEmpty(series.json)
            ])
        }
        
    }
    
    @available(*, deprecated, message: "Use `title.string(forLanguageCode:)` instead")
    public func titleForLang(_ lang: String) -> String? {
        return title.string(forLanguageCode: lang)
    }
    
    @available(*, deprecated, message: "Use `subtitle.string(forLanguageCode:)` instead")
    public func subtitleForLang(_ lang: String) -> String? {
        return subtitle?.string(forLanguageCode: lang)
    }
    
}
