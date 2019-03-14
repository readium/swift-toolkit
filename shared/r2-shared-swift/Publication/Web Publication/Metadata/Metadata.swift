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


/// https://readium.org/webpub-manifest/schema/metadata.schema.json
public struct Metadata: Equatable, Loggable {

    /// Collection type used for collection/series metadata.
    /// For convenience, the JSON schema reuse the Contributor's definition.
    public typealias Collection = Contributor


    public var identifier: String?  // URI
    public var type: String?  // URI (@type)
    
    public var localizedTitle: LocalizedString
    public var title: String {
        get { return localizedTitle.string }
        set { localizedTitle = newValue.localizedString }
    }
    
    public var localizedSubtitle: LocalizedString?
    public var subtitle: String? {
        get { return localizedSubtitle?.string }
        set { localizedSubtitle = newValue?.localizedString }
    }
    
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
    public var belongsToCollections: [Collection]
    public var belongsToSeries: [Collection]


    /// Additional properties for extensions.
    public var otherMetadata: [String: Any] {
        get { return otherMetadataJSON.json }
        set { otherMetadataJSON.json = newValue }
    }
    // Trick to keep the struct equatable despite [String: Any]
    private var otherMetadataJSON: JSONDictionary

    
    public init(identifier: String? = nil, type: String? = nil, title: LocalizedStringConvertible, subtitle: LocalizedStringConvertible? = nil, modified: Date? = nil, published: Date? = nil, languages: [String] = [], sortAs: String? = nil, subjects: [Subject] = [], authors: [Contributor] = [], translators: [Contributor] = [], editors: [Contributor] = [], artists: [Contributor] = [], illustrators: [Contributor] = [], letterers: [Contributor] = [], pencilers: [Contributor] = [], colorists: [Contributor] = [], inkers: [Contributor] = [], narrators: [Contributor] = [], contributors: [Contributor] = [], publishers: [Contributor] = [], imprints: [Contributor] = [], readingProgression: ReadingProgression = .auto, description: String? = nil, duration: Double? = nil, numberOfPages: Int? = nil, belongsToCollections: [Collection] = [], belongsToSeries: [Collection] = [], otherMetadata: [String: Any] = [:]) {
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
        self.belongsToCollections = [Collection](json: belongsTo?["collection"])
        self.belongsToSeries = [Collection](json: belongsTo?["series"])
        self.otherMetadataJSON = json
    }
    
    var json: [String: Any] {
        let belongsTo = makeJSON([
            "collection": encodeIfNotEmpty(belongsToCollections.json),
            "series": encodeIfNotEmpty(belongsToSeries.json)
        ])
        
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
            "belongsTo": encodeIfNotEmpty(belongsTo)
        ], additional: otherMetadata)
    }

}
