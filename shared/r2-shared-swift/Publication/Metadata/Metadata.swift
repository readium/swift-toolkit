//
//  Metadata.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu, Alexandre Camilleri on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// Collection struct used for collection/series metadata.
/// For convenience, the JSON schema reuse the Contributor's definition.
public typealias PublicationCollection = Contributor


/// https://readium.org/webpub-manifest/schema/metadata.schema.json
public struct Metadata: Equatable {

    public var identifier: String?  // URI
    public var type: String?  // URI (@type)
    public var localizedTitle: LocalizedString
    public var title: String { return localizedTitle.string }
    public var localizedSubtitle: LocalizedString?
    public var subtitle: String? { return localizedSubtitle?.string }
    public var modified: Date?
    public var published: Date?
    public var languages: [String]  // BCP 47 tag
    public var sortAs: String?
    public var subjects: [Subject]
    public var authors: [Contributor]
    public var translators: [Contributor]
    public var editors: [Contributor]
    public var artists: [Contributor]
    public var illustrators: [Contributor]
    public var letterers: [Contributor]
    public var pencilers: [Contributor]
    public var colorists: [Contributor]
    public var inkers: [Contributor]
    public var narrators: [Contributor]
    public var contributors: [Contributor]
    public var publishers: [Contributor]
    public var imprints: [Contributor]
    public var readingProgression: ReadingProgression
    public var description: String?
    public var duration: Double?
    public var numberOfPages: Int?
    public var belongsToCollections: [PublicationCollection]
    public var belongsToSeries: [PublicationCollection]

    
    // MARK: - EPUB Extension
    
    public var rendition: EPUBRendition?
    
    
    /// Additional properties for extensions.
    public var otherMetadata: [String: Any] {
        get { return otherMetadataJSON.json }
        set { otherMetadataJSON.json = newValue }
    }
    // Trick to keep the struct equatable despite [String: Any]
    private var otherMetadataJSON: JSONDictionary
    
    
    /// FIXME: Move to Publication
    public var contentLayout: ContentLayoutStyle {
        return contentLayout(forLanguage: nil)
    }
    
    public func contentLayout(forLanguage language: String?) -> ContentLayoutStyle {
        let language = (language?.isEmpty ?? true) ? nil : language
        return ContentLayoutStyle(
            language: language ?? languages.first ?? "",
            readingProgression: readingProgression
        )
    }

    
    public init(identifier: String? = nil, type: String? = nil, title: LocalizedStringConvertible, subtitle: LocalizedStringConvertible? = nil, modified: Date? = nil, published: Date? = nil, languages: [String] = [], sortAs: String? = nil, subjects: [Subject] = [], authors: [Contributor] = [], translators: [Contributor] = [], editors: [Contributor] = [], artists: [Contributor] = [], illustrators: [Contributor] = [], letterers: [Contributor] = [], pencilers: [Contributor] = [], colorists: [Contributor] = [], inkers: [Contributor] = [], narrators: [Contributor] = [], contributors: [Contributor] = [], publishers: [Contributor] = [], imprints: [Contributor] = [], readingProgression: ReadingProgression = .auto, description: String? = nil, duration: Double? = nil, numberOfPages: Int? = nil, belongsToCollections: [PublicationCollection] = [], belongsToSeries: [PublicationCollection] = [], rendition: EPUBRendition? = nil, otherMetadata: [String: Any] = [:]) {
        self.identifier = identifier
        self.type = type
        self.localizedTitle = title.localizedString
        self.localizedSubtitle = subtitle?.localizedString
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
        self.belongsToCollections = belongsToCollections
        self.belongsToSeries = belongsToSeries
        self.rendition = rendition
        self.otherMetadataJSON = JSONDictionary(otherMetadata) ?? JSONDictionary()
    }
    
    init(json: Any?) throws {
        guard var json = JSONDictionary(json),
            let title = try LocalizedString(json: json.pop("title")) else
        {
            throw JSONParsingError.metadata
        }
        
        self.identifier = json.pop("identifier") as? String
        self.type = json.pop("@type") as? String ?? json.pop("type") as? String
        self.localizedTitle = title
        self.localizedSubtitle = try LocalizedString(json: json.pop("subtitle"))
        self.modified = parseDate(json.pop("modified"))
        self.published = parseDate(json.pop("published"))
        self.languages = parseArray(json.pop("language"), allowingSingle: true)
        self.sortAs = json.pop("sortAs") as? String
        self.subjects = [Subject](json: json.pop("subject"))
        self.authors = [Contributor](json: json.pop("author"))
        self.translators = [Contributor](json: json.pop("translator"))
        self.editors = [Contributor](json: json.pop("editor"))
        self.artists = [Contributor](json: json.pop("artist"))
        self.illustrators = [Contributor](json: json.pop("illustrator"))
        self.letterers = [Contributor](json: json.pop("letterer"))
        self.pencilers = [Contributor](json: json.pop("penciler"))
        self.colorists = [Contributor](json: json.pop("colorist"))
        self.inkers = [Contributor](json: json.pop("inker"))
        self.narrators = [Contributor](json: json.pop("narrator"))
        self.contributors = [Contributor](json: json.pop("contributor"))
        self.publishers = [Contributor](json: json.pop("publisher"))
        self.imprints = [Contributor](json: json.pop("imprint"))
        self.readingProgression = parseRaw(json.pop("readingProgression")) ?? .auto
        self.description = json.pop("description") as? String
        self.duration = parsePositiveDouble(json.pop("duration"))
        self.numberOfPages = parsePositive(json.pop("numberOfPages"))
        let belongsTo = json.pop("belongsTo") as? [String: Any]
        self.belongsToCollections = [PublicationCollection](json: belongsTo?["collection"])
        self.belongsToSeries = [PublicationCollection](json: belongsTo?["series"])
        self.rendition = try EPUBRendition(json: json.pop("rendition"))
        self.otherMetadataJSON = json
    }
    
    var json: [String: Any] {
        let belongsTo = [
            "collection": encodeIfNotEmpty(belongsToCollections.json),
            "series": encodeIfNotEmpty(belongsToSeries.json)
        ]
        
        return makeJSON([
            "identifier": encodeIfNotNil(identifier),
            "@type": encodeIfNotNil(type),
            "title": localizedTitle.json,
            "subtitle": encodeIfNotNil(localizedSubtitle?.json),
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
            "belongsTo": encodeIfNotEmpty(belongsTo),
            "rendition": encodeIfNotEmpty(rendition?.json)
        ], additional: otherMetadata)
    }

    @available(*, deprecated, renamed: "type")
    public var rdfType: String? {
        get { return type }
        set { type = newValue }
    }

    @available(*, deprecated, renamed: "localizedTitle")
    public var multilangTitle: LocalizedString {
        get { return localizedTitle }
        set { localizedTitle = newValue }
    }

    @available(*, deprecated, renamed: "localizedSubtitle")
    public var multilangSubtitle: LocalizedString? {
        get { return localizedSubtitle }
        set { localizedSubtitle = newValue }
    }

    @available(*, unavailable, message: "Not used anymore, you can store the rights in `otherMetadata[\"rights\"]` if necessary")
    public var rights: String? { get { return nil } set {} }

    @available(*, unavailable, message: "Not used anymore, you can store the source in `otherMetadata[\"source\"]` if necessary")
    public var source: String? { get { return nil } set {} }

    @available(*, deprecated, renamed: "Metadata(title:)")
    public init() {
        self.init(title: "")
    }

    @available(*, deprecated, message: "Use `localizedTitle.string(forLanguageCode:)` instead")
    public func titleForLang(_ lang: String) -> String? {
        return localizedTitle.string(forLanguageCode: lang)
    }
    
    @available(*, deprecated, message: "Use `localizedSubtitle.string(forLanguageCode:)` instead")
    public func subtitleForLang(_ lang: String) -> String? {
        return localizedSubtitle?.string(forLanguageCode: lang)
    }
    
    @available(*, deprecated, renamed: "Metadata(json:)")
    public static func parse(metadataDict: [String: Any]) throws -> Metadata {
        return try Metadata(json: metadataDict)
    }
    
}
