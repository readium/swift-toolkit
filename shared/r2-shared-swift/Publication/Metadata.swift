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

    public let identifier: String?  // URI
    public let type: String?  // URI (@type)
    
    public let localizedTitle: LocalizedString
    public var title: String { localizedTitle.string }

    public let localizedSubtitle: LocalizedString?
    public var subtitle: String? { localizedSubtitle?.string }

    public let modified: Date?
    public let published: Date?
    public let languages: [String]  // BCP 47 tag
    public let sortAs: String?
    public let subjects: [Subject]
    public let authors: [Contributor]
    public let translators: [Contributor]
    public let editors: [Contributor]
    public let artists: [Contributor]
    public let illustrators: [Contributor]
    public let letterers: [Contributor]
    public let pencilers: [Contributor]
    public let colorists: [Contributor]
    public let inkers: [Contributor]
    public let narrators: [Contributor]
    public let contributors: [Contributor]
    public let publishers: [Contributor]
    public let imprints: [Contributor]
    /// WARNING: This contains the reading progression as declared in the publication, so it might be `auto`. To lay out the content, use `publication.contentLayout.readingProgression` to get the calculated reading progression from the declared direction and the language.
    public let readingProgression: ReadingProgression
    public let description: String?
    public let duration: Double?
    public let numberOfPages: Int?
    public let belongsToCollections: [Collection]
    public let belongsToSeries: [Collection]


    /// Additional properties for extensions.
    public var otherMetadata: [String: Any] { otherMetadataJSON.json }
    
    // Trick to keep the struct equatable despite [String: Any]
    private let otherMetadataJSON: JSONDictionary

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
    
    init(json: Any?, normalizeHref: (String) -> String = { $0 }) throws {
        guard var json = JSONDictionary(json),
            let title = try LocalizedString(json: json.pop("title")) else
        {
            throw JSONError.parsing(Metadata.self)
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
        self.authors = [Contributor](json: json.pop("author"), normalizeHref: normalizeHref)
        self.translators = [Contributor](json: json.pop("translator"), normalizeHref: normalizeHref)
        self.editors = [Contributor](json: json.pop("editor"), normalizeHref: normalizeHref)
        self.artists = [Contributor](json: json.pop("artist"), normalizeHref: normalizeHref)
        self.illustrators = [Contributor](json: json.pop("illustrator"), normalizeHref: normalizeHref)
        self.letterers = [Contributor](json: json.pop("letterer"), normalizeHref: normalizeHref)
        self.pencilers = [Contributor](json: json.pop("penciler"), normalizeHref: normalizeHref)
        self.colorists = [Contributor](json: json.pop("colorist"), normalizeHref: normalizeHref)
        self.inkers = [Contributor](json: json.pop("inker"), normalizeHref: normalizeHref)
        self.narrators = [Contributor](json: json.pop("narrator"), normalizeHref: normalizeHref)
        self.contributors = [Contributor](json: json.pop("contributor"), normalizeHref: normalizeHref)
        self.publishers = [Contributor](json: json.pop("publisher"), normalizeHref: normalizeHref)
        self.imprints = [Contributor](json: json.pop("imprint"), normalizeHref: normalizeHref)
        self.readingProgression = parseRaw(json.pop("readingProgression")) ?? .auto
        self.description = json.pop("description") as? String
        self.duration = parsePositiveDouble(json.pop("duration"))
        self.numberOfPages = parsePositive(json.pop("numberOfPages"))
        let belongsTo = json.pop("belongsTo") as? [String: Any]
        self.belongsToCollections = [Collection](json: belongsTo?["collection"], normalizeHref: normalizeHref)
        self.belongsToSeries = [Collection](json: belongsTo?["series"], normalizeHref: normalizeHref)
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
    
    /// Makes a copy of the `Metadata`, after modifying some of its properties.
    public func copy(
        identifier: String?? = nil,
        type: String?? = nil,
        title: LocalizedStringConvertible? = nil,
        subtitle: LocalizedStringConvertible?? = nil,
        modified: Date?? = nil,
        published: Date?? = nil,
        languages: [String]? = nil,
        sortAs: String?? = nil,
        subjects: [Subject]? = nil,
        authors: [Contributor]? = nil,
        translators: [Contributor]? = nil,
        editors: [Contributor]? = nil,
        artists: [Contributor]? = nil,
        illustrators: [Contributor]? = nil,
        letterers: [Contributor]? = nil,
        pencilers: [Contributor]? = nil,
        colorists: [Contributor]? = nil,
        inkers: [Contributor]? = nil,
        narrators: [Contributor]? = nil,
        contributors: [Contributor]? = nil,
        publishers: [Contributor]? = nil,
        imprints: [Contributor]? = nil,
        readingProgression: ReadingProgression? = nil,
        description: String?? = nil,
        duration: Double?? = nil,
        numberOfPages: Int?? = nil,
        belongsToCollections: [Collection]? = nil,
        belongsToSeries: [Collection]? = nil,
        otherMetadata: [String: Any]? = nil
    ) -> Metadata {
        return Metadata(
            identifier: identifier ?? self.identifier,
            type: type ?? self.type,
            title: title ?? self.localizedTitle,
            subtitle: subtitle ?? self.localizedSubtitle,
            modified: modified ?? self.modified,
            published: published ?? self.published,
            languages: languages ?? self.languages,
            sortAs: sortAs ?? self.sortAs,
            subjects: subjects ?? self.subjects,
            authors: authors ?? self.authors,
            translators: translators ?? self.translators,
            editors: editors ?? self.editors,
            artists: artists ?? self.artists,
            illustrators: illustrators ?? self.illustrators,
            letterers: letterers ?? self.letterers,
            pencilers: pencilers ?? self.pencilers,
            colorists: colorists ?? self.colorists,
            inkers: inkers ?? self.inkers,
            narrators: narrators ?? self.narrators,
            contributors: contributors ?? self.contributors,
            publishers: publishers ?? self.publishers,
            imprints: imprints ?? self.imprints,
            readingProgression: readingProgression ?? self.readingProgression,
            description: description ?? self.description,
            duration: duration ?? self.duration,
            numberOfPages: numberOfPages ?? self.numberOfPages,
            belongsToCollections: belongsToCollections ?? self.belongsToCollections,
            belongsToSeries: belongsToSeries ?? self.belongsToSeries,
            otherMetadata: otherMetadata ?? self.otherMetadata
        )
    }

}
