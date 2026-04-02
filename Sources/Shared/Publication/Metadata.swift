//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Holds the metadata of a Readium publication, as described in the Readium Web Publication
/// Manifest.
///
/// See. https://readium.org/webpub-manifest/
public struct Metadata: Hashable, Loggable, WarningLogger, Sendable, JSONValueDecodable, JSONObjectEncodable {
    /// Collection type used for collection/series metadata.
    /// For convenience, the JSON schema reuse the Contributor's definition.
    public typealias Collection = Contributor

    public var identifier: String? // URI
    public var type: String? // URI (@type)
    public var conformsTo: [Publication.Profile]

    public var localizedTitle: LocalizedString?
    public var title: String? {
        localizedTitle?.string
    }

    public var localizedSubtitle: LocalizedString?
    public var subtitle: String? {
        localizedSubtitle?.string
    }

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
    public var otherMetadata: [String: JSONValue]

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
        otherMetadata: [String: JSONValue] = [:]
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
        self.otherMetadata = otherMetadata
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard var jsonObject = json?.jsonValue.object,
              let title: LocalizedString = try? jsonObject.pop("title")?.decode(warnings: warnings)
        else {
            throw JSONError.parsing(Metadata.self)
        }

        identifier = jsonObject.pop("identifier")?.string
        type = jsonObject.pop("@type")?.string ?? jsonObject.pop("type")?.string
        conformsTo = jsonObject.pop("conformsTo")?.decode(allowingSingle: true) ?? []
        localizedTitle = title
        localizedSubtitle = try? jsonObject.pop("subtitle")?.decode(warnings: warnings)
        accessibility = try? jsonObject.pop("accessibility")?.decode(warnings: warnings)
        modified = jsonObject.pop("modified")?.date
        published = jsonObject.pop("published")?.date
        languages = jsonObject.pop("language")?.decode(allowingSingle: true) ?? []
        language = languages.first.map { Language(code: .bcp47($0)) }
        sortAs = jsonObject.pop("sortAs")?.string
        subjects = jsonObject.pop("subject")?.decode(allowingSingle: true, warnings: warnings) ?? []
        authors = jsonObject.pop("author")?.decode(allowingSingle: true, warnings: warnings) ?? []
        translators = jsonObject.pop("translator")?.decode(allowingSingle: true, warnings: warnings) ?? []
        editors = jsonObject.pop("editor")?.decode(allowingSingle: true, warnings: warnings) ?? []
        artists = jsonObject.pop("artist")?.decode(allowingSingle: true, warnings: warnings) ?? []
        illustrators = jsonObject.pop("illustrator")?.decode(allowingSingle: true, warnings: warnings) ?? []
        letterers = jsonObject.pop("letterer")?.decode(allowingSingle: true, warnings: warnings) ?? []
        pencilers = jsonObject.pop("penciler")?.decode(allowingSingle: true, warnings: warnings) ?? []
        colorists = jsonObject.pop("colorist")?.decode(allowingSingle: true, warnings: warnings) ?? []
        inkers = jsonObject.pop("inker")?.decode(allowingSingle: true, warnings: warnings) ?? []
        narrators = jsonObject.pop("narrator")?.decode(allowingSingle: true, warnings: warnings) ?? []
        contributors = jsonObject.pop("contributor")?.decode(allowingSingle: true, warnings: warnings) ?? []
        publishers = jsonObject.pop("publisher")?.decode(allowingSingle: true, warnings: warnings) ?? []
        imprints = jsonObject.pop("imprint")?.decode(allowingSingle: true, warnings: warnings) ?? []
        layout = jsonObject.pop("layout")?.decode()
        readingProgression = jsonObject.pop("readingProgression")?.decode() ?? .auto
        description = jsonObject.pop("description")?.string
        duration = jsonObject.pop("duration")?.nonNegative()
        numberOfPages = jsonObject.pop("numberOfPages")?.nonNegative()
        belongsTo = jsonObject.pop("belongsTo")?.object?
            .compactMapValues { $0.decode(allowingSingle: true, warnings: warnings) }
            ?? [:]
        tdm = try? jsonObject.pop("tdm")?.decode(warnings: warnings)
        otherMetadata = jsonObject
    }

    public var jsonObject: [String: JSONValue] {
        .init([
            "identifier": identifier,
            "@type": type,
            "conformsTo": conformsTo.map(\.uri).orNullIfEmpty,
            "title": localizedTitle,
            "subtitle": localizedSubtitle,
            "accessibility": accessibility,
            "modified": modified?.iso8601,
            "published": published?.iso8601,
            "language": languages.orNullIfEmpty,
            "sortAs": sortAs,
            "subject": subjects.orNullIfEmpty,
            "author": authors.orNullIfEmpty,
            "translator": translators.orNullIfEmpty,
            "editor": editors.orNullIfEmpty,
            "artist": artists.orNullIfEmpty,
            "illustrator": illustrators.orNullIfEmpty,
            "letterer": letterers.orNullIfEmpty,
            "penciler": pencilers.orNullIfEmpty,
            "colorist": colorists.orNullIfEmpty,
            "inker": inkers.orNullIfEmpty,
            "narrator": narrators.orNullIfEmpty,
            "contributor": contributors.orNullIfEmpty,
            "publisher": publishers.orNullIfEmpty,
            "imprint": imprints.orNullIfEmpty,
            "layout": layout?.rawValue,
            "readingProgression": readingProgression.rawValue,
            "description": description,
            "duration": duration,
            "numberOfPages": numberOfPages,
            "belongsTo": belongsTo.mapValues(\.jsonValue).orNullIfEmpty,
            "tdm": tdm,
        ], adding: otherMetadata)
    }

    public var belongsToCollections: [Collection] {
        belongsTo["collection"] ?? []
    }

    public var belongsToSeries: [Collection] {
        belongsTo["series"] ?? []
    }
}
