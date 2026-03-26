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

    public init?(
        json: JSONValue?,
        warnings: WarningLogger? = nil
    ) throws {
        guard var jsonObject = json?.object,
              let title = try? LocalizedString(json: jsonObject.pop("title"), warnings: warnings)
        else {
            throw JSONError.parsing(Metadata.self)
        }

        identifier = jsonObject.pop("identifier")?.string
        type = jsonObject.pop("@type")?.string ?? jsonObject.pop("type")?.string
        conformsTo = (jsonObject.pop("conformsTo")?.parseArray(allowingSingle: true) as [String]? ?? [])
            .map { Publication.Profile($0) }
        localizedTitle = title
        localizedSubtitle = try? LocalizedString(json: jsonObject.pop("subtitle"), warnings: warnings)
        accessibility = try? Accessibility(json: jsonObject.pop("accessibility"), warnings: warnings)
        modified = jsonObject.pop("modified")?.parseDate()
        published = jsonObject.pop("published")?.parseDate()
        languages = jsonObject.pop("language")?.parseArray(allowingSingle: true) ?? []
        language = languages.first.map { Language(code: .bcp47($0)) }
        sortAs = jsonObject.pop("sortAs")?.string
        subjects = jsonObject.pop("subject")?.arrayOf(warnings: warnings) ?? []
        authors = jsonObject.pop("author")?.arrayOf(warnings: warnings) ?? []
        translators = jsonObject.pop("translator")?.arrayOf(warnings: warnings) ?? []
        editors = jsonObject.pop("editor")?.arrayOf(warnings: warnings) ?? []
        artists = jsonObject.pop("artist")?.arrayOf(warnings: warnings) ?? []
        illustrators = jsonObject.pop("illustrator")?.arrayOf(warnings: warnings) ?? []
        letterers = jsonObject.pop("letterer")?.arrayOf(warnings: warnings) ?? []
        pencilers = jsonObject.pop("penciler")?.arrayOf(warnings: warnings) ?? []
        colorists = jsonObject.pop("colorist")?.arrayOf(warnings: warnings) ?? []
        inkers = jsonObject.pop("inker")?.arrayOf(warnings: warnings) ?? []
        narrators = jsonObject.pop("narrator")?.arrayOf(warnings: warnings) ?? []
        contributors = jsonObject.pop("contributor")?.arrayOf(warnings: warnings) ?? []
        publishers = jsonObject.pop("publisher")?.arrayOf(warnings: warnings) ?? []
        imprints = jsonObject.pop("imprint")?.arrayOf(warnings: warnings) ?? []
        layout = jsonObject.pop("layout")?.parseRaw()
        readingProgression = jsonObject.pop("readingProgression")?.parseRaw() ?? .auto
        description = jsonObject.pop("description")?.string
        duration = jsonObject.pop("duration")?.parsePositiveDouble()
        numberOfPages = jsonObject.pop("numberOfPages")?.parsePositive()
        belongsTo = jsonObject.pop("belongsTo")?.object?
            .compactMapValues { item in .init(json: item, warnings: warnings) }
            ?? [:]
        tdm = try? TDM(json: jsonObject.pop("tdm"), warnings: warnings)
        otherMetadata = jsonObject
    }

    public var jsonObject: [String: JSONValue] {
        .init([
            "identifier": identifier,
            "@type": type,
            "conformsTo": conformsTo.isEmpty ? JSONValue.null : conformsTo.map(\.uri),
            "title": localizedTitle,
            "subtitle": localizedSubtitle,
            "accessibility": accessibility,
            "modified": modified?.iso8601,
            "published": published?.iso8601,
            "language": languages.isEmpty ? JSONValue.null : languages,
            "sortAs": sortAs,
            "subject": subjects.isEmpty ? JSONValue.null : subjects,
            "author": authors.isEmpty ? JSONValue.null : authors,
            "translator": translators.isEmpty ? JSONValue.null : translators,
            "editor": editors.isEmpty ? JSONValue.null : editors,
            "artist": artists.isEmpty ? JSONValue.null : artists,
            "illustrator": illustrators.isEmpty ? JSONValue.null : illustrators,
            "letterer": letterers.isEmpty ? JSONValue.null : letterers,
            "penciler": pencilers.isEmpty ? JSONValue.null : pencilers,
            "colorist": colorists.isEmpty ? JSONValue.null : colorists,
            "inker": inkers.isEmpty ? JSONValue.null : inkers,
            "narrator": narrators.isEmpty ? JSONValue.null : narrators,
            "contributor": contributors.isEmpty ? JSONValue.null : contributors,
            "publisher": publishers.isEmpty ? JSONValue.null : publishers,
            "imprint": imprints.isEmpty ? JSONValue.null : imprints,
            "layout": layout?.rawValue,
            "readingProgression": readingProgression.rawValue,
            "description": description,
            "duration": duration,
            "numberOfPages": numberOfPages,
            "belongsTo": belongsTo.isEmpty ? JSONValue.null : .object(belongsTo.mapValues { .array($0.map { .object($0.jsonObject) }) }),
            "tdm": tdm,
        ], additional: otherMetadata)
    }

    public var belongsToCollections: [Collection] {
        belongsTo["collection"] ?? []
    }

    public var belongsToSeries: [Collection] {
        belongsTo["series"] ?? []
    }
}
