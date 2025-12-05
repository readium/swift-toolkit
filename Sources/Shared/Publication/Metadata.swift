//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// https://readium.org/webpub-manifest/schema/metadata.schema.json
public struct Metadata: Hashable, Loggable, WarningLogger, Sendable {
    /// Collection type used for collection/series metadata.
    /// For convenience, the JSON schema reuse the Contributor's definition.
    public typealias Collection = Contributor

    public var identifier: String? // URI
    public var type: String? // URI (@type)
    public var conformsTo: [Publication.Profile]

    public var localizedTitle: LocalizedString?
    public var title: String? { localizedTitle?.string }

    public var localizedSubtitle: LocalizedString?
    public var subtitle: String? { localizedSubtitle?.string }

    public var accessibility: Accessibility?
    public var modified: Date?
    public var published: Date?
    public var languages: [String] // BCP 47 tag
    // Main language of the publication.
    public var language: Language?
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
    public var description: String?
    public var duration: Double?
    public var numberOfPages: Int?
    public var belongsTo: [String: [Collection]]

    /// Publications can indicate whether they allow third parties to use their
    /// content for text and data mining purposes using the [TDM Rep protocol](https://www.w3.org/community/tdmrep/),
    /// as defined in a [W3C Community Group Report](https://www.w3.org/community/reports/tdmrep/CG-FINAL-tdmrep-20240510/).
    public var tdm: TDM?

    /// Hint about the nature of the layout for the publication.
    ///
    /// https://readium.org/webpub-manifest/contexts/default/#layout-and-reading-progression
    public var layout: Layout?

    public var readingProgression: ReadingProgression

    /// Additional properties for extensions.
    public var otherMetadata: JSONDictionary.Wrapped {
        get { otherMetadataJSON.json }
        set { otherMetadataJSON = JSONDictionary(newValue) ?? JSONDictionary() }
    }

    // Trick to keep the struct equatable despite [String: Any]
    private var otherMetadataJSON: JSONDictionary

    public init(
        identifier: String? = nil,
        type: String? = nil,
        conformsTo: [Publication.Profile] = [],
        title: LocalizedStringConvertible? = nil,
        subtitle: LocalizedStringConvertible? = nil,
        accessibility: Accessibility? = nil,
        modified: Date? = nil,
        published: Date? = nil,
        languages: [String] = [],
        sortAs: String? = nil,
        subjects: [Subject] = [],
        authors: [Contributor] = [],
        translators: [Contributor] = [],
        editors: [Contributor] = [],
        artists: [Contributor] = [],
        illustrators: [Contributor] = [],
        letterers: [Contributor] = [],
        pencilers: [Contributor] = [],
        colorists: [Contributor] = [],
        inkers: [Contributor] = [],
        narrators: [Contributor] = [],
        contributors: [Contributor] = [],
        publishers: [Contributor] = [],
        imprints: [Contributor] = [],
        layout: Layout? = nil,
        readingProgression: ReadingProgression = .auto,
        description: String? = nil,
        duration: Double? = nil,
        numberOfPages: Int? = nil,
        belongsTo: [String: [Collection]] = [:],
        belongsToCollections: [Collection] = [],
        belongsToSeries: [Collection] = [],
        tdm: TDM? = nil,
        otherMetadata: JSONDictionary.Wrapped = [:]
    ) {
        self.identifier = identifier
        self.type = type
        self.conformsTo = conformsTo
        localizedTitle = title?.localizedString
        localizedSubtitle = subtitle?.localizedString
        self.accessibility = accessibility
        self.modified = modified
        self.published = published
        self.languages = languages
        language = languages.first.map { Language(code: .bcp47($0)) }
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
        self.layout = layout
        self.readingProgression = readingProgression
        self.description = description
        self.duration = duration
        self.numberOfPages = numberOfPages

        var belongsTo = belongsTo
        if !belongsToCollections.isEmpty {
            belongsTo["collection"] = belongsToCollections
        }
        if !belongsToSeries.isEmpty {
            belongsTo["series"] = belongsToSeries
        }
        self.belongsTo = belongsTo

        self.tdm = tdm

        otherMetadataJSON = JSONDictionary(otherMetadata) ?? JSONDictionary()
    }

    public init(
        json: Any?,
        warnings: WarningLogger? = nil
    ) throws {
        guard var json = JSONDictionary(json),
              let title = try? LocalizedString(json: json.pop("title"), warnings: warnings)
        else {
            throw JSONError.parsing(Metadata.self)
        }

        identifier = json.pop("identifier") as? String
        type = json.pop("@type") as? String ?? json.pop("type") as? String
        conformsTo = parseArray(json.pop("conformsTo"), allowingSingle: true)
            .map { Publication.Profile($0) }
        localizedTitle = title
        localizedSubtitle = try? LocalizedString(json: json.pop("subtitle"), warnings: warnings)
        accessibility = try? Accessibility(json: json.pop("accessibility"), warnings: warnings)
        modified = parseDate(json.pop("modified"))
        published = parseDate(json.pop("published"))
        languages = parseArray(json.pop("language"), allowingSingle: true)
        language = languages.first.map { Language(code: .bcp47($0)) }
        sortAs = json.pop("sortAs") as? String
        subjects = [Subject](json: json.pop("subject"), warnings: warnings)
        authors = [Contributor](json: json.pop("author"), warnings: warnings)
        translators = [Contributor](json: json.pop("translator"), warnings: warnings)
        editors = [Contributor](json: json.pop("editor"), warnings: warnings)
        artists = [Contributor](json: json.pop("artist"), warnings: warnings)
        illustrators = [Contributor](json: json.pop("illustrator"), warnings: warnings)
        letterers = [Contributor](json: json.pop("letterer"), warnings: warnings)
        pencilers = [Contributor](json: json.pop("penciler"), warnings: warnings)
        colorists = [Contributor](json: json.pop("colorist"), warnings: warnings)
        inkers = [Contributor](json: json.pop("inker"), warnings: warnings)
        narrators = [Contributor](json: json.pop("narrator"), warnings: warnings)
        contributors = [Contributor](json: json.pop("contributor"), warnings: warnings)
        publishers = [Contributor](json: json.pop("publisher"), warnings: warnings)
        imprints = [Contributor](json: json.pop("imprint"), warnings: warnings)
        layout = parseRaw(json.pop("layout"))
        readingProgression = parseRaw(json.pop("readingProgression")) ?? .auto
        description = json.pop("description") as? String
        duration = parsePositiveDouble(json.pop("duration"))
        numberOfPages = parsePositive(json.pop("numberOfPages"))
        belongsTo = (json.pop("belongsTo") as? JSONDictionary.Wrapped)?
            .compactMapValues { item in [Collection](json: item, warnings: warnings) }
            ?? [:]
        tdm = try? TDM(json: json.pop("tdm"), warnings: warnings)
        otherMetadataJSON = json
    }

    public var json: JSONDictionary.Wrapped {
        makeJSON([
            "identifier": encodeIfNotNil(identifier),
            "@type": encodeIfNotNil(type),
            "conformsTo": encodeIfNotEmpty(conformsTo.map(\.uri)),
            "title": encodeIfNotNil(localizedTitle?.json),
            "subtitle": encodeIfNotNil(localizedSubtitle?.json),
            "accessibility": encodeIfNotEmpty(accessibility?.json),
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
            "layout": encodeIfNotNil(layout?.rawValue),
            "readingProgression": readingProgression.rawValue,
            "description": encodeIfNotNil(description),
            "duration": encodeIfNotNil(duration),
            "numberOfPages": encodeIfNotNil(numberOfPages),
            "belongsTo": encodeIfNotEmpty(belongsTo.mapValues { $0.json }),
            "tdm": encodeIfNotEmpty(tdm?.json),
        ], additional: otherMetadata)
    }

    public var belongsToCollections: [Collection] {
        belongsTo["collection"] ?? []
    }

    public var belongsToSeries: [Collection] {
        belongsTo["series"] ?? []
    }
}
