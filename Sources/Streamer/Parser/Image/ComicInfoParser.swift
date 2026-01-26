//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumFuzi
import ReadiumShared

/// Parses ComicInfo.xml metadata from CBZ archives.
///
/// ComicInfo.xml is a metadata format originating from the ComicRack
/// application.
/// See: https://anansi-project.github.io/docs/comicinfo/documentation
struct ComicInfoParser {
    /// Parses ComicInfo.xml data and returns the parsed metadata.
    static func parse(data: Data, warnings: WarningLogger?) -> ComicInfo? {
        guard let document = try? XMLDocument(data: data) else {
            warnings?.log(ComicInfoWarning(message: "Failed to parse ComicInfo.xml"))
            return nil
        }

        guard let root = document.root, root.tag == "ComicInfo" else {
            warnings?.log(ComicInfoWarning(message: "ComicInfo.xml root element is not <ComicInfo>"))
            return nil
        }

        return ComicInfo(element: root)
    }
}

/// Warning raised when parsing a ComicInfo.xml file.
struct ComicInfoWarning: Warning {
    let message: String
    var severity: WarningSeverityLevel { .minor }
    var tag: String { "comicinfo" }
}

/// Parsed representation of ComicInfo.xml data.
///
/// Only metadata fields that map to RWPM are exposed as first-class properties.
/// All other fields are available in the `otherMetadata` dictionary.
///
/// See https://anansi-project.github.io/docs/comicinfo/documentation
struct ComicInfo {
    /// Title of the book.
    var title: String?

    /// Title of the series the book is part of.
    var series: String?

    /// Number of the book in the series.
    var number: String?

    /// Alternate series name, used for cross-over story arcs.
    var alternateSeries: String?

    /// Number of the book in the alternate series.
    var alternateNumber: String?

    /// A description or summary of the book.
    var summary: String?

    /// Person or organization responsible for publishing, releasing, or
    /// issuing a resource.
    var publisher: String?

    /// An imprint is a group of publications under the umbrella of a larger
    /// imprint or publisher.
    var imprint: String?

    /// Release year of the book.
    var year: Int?

    /// Release month of the book.
    var month: Int?

    /// Release day of the book.
    var day: Int?

    /// Language of the book using IETF BCP 47 language tags.
    var languageISO: String?

    /// Global Trade Item Number identifying the book (ISBN, EAN, etc.).
    var gtin: String?

    /// People or organizations responsible for creating the scenario.
    var writers: [String] = []

    /// People or organizations responsible for drawing the art.
    var pencillers: [String] = []

    /// People or organizations responsible for inking the pencil art.
    var inkers: [String] = []

    /// People or organizations responsible for applying color to drawings.
    var colorists: [String] = []

    /// People or organizations responsible for drawing text and speech bubbles.
    var letterers: [String] = []

    /// People or organizations responsible for drawing the cover art.
    var coverArtists: [String] = []

    /// People or organizations responsible for preparing the resource for
    /// production.
    var editors: [String] = []

    /// People or organizations responsible for rendering text from one language
    /// into another.
    var translators: [String] = []

    /// Genres of the book or series (e.g., Science-Fiction, Shonen).
    var genres: [String] = []

    /// Whether the book is a manga. The value `.yesAndRightToLeft` indicates
    /// right-to-left reading direction.
    var manga: Manga?

    /// Page information parsed from the <Pages> element.
    var pages: [PageInfo] = []

    /// Returns the first page with the given type, if any.
    func firstPageWithType(_ type: PageType) -> PageInfo? {
        pages.first { $0.type == type }
    }

    /// All other metadata fields not directly mapped to RWPM.
    ///
    /// Keys are the XML tag names (e.g., "Volume", "Characters", "AgeRating").
    /// Values are strings as they appear in the XML.
    var otherMetadata: [String: String] = [:]

    /// URL prefix for otherMetadata keys when converting to RWPM.
    private static let otherMetadataPrefix = "https://anansi-project.github.io/docs/comicinfo/documentation#"

    init(element: ReadiumFuzi.XMLElement) {
        for child in element.children {
            guard let tag = child.tag else { continue }

            // Pages element has no text content, only child elements
            if tag == "Pages" {
                pages = child.children(tag: "Page").compactMap { PageInfo(element: $0) }
                continue
            }

            let value = child.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }

            switch tag {
            // Core
            case "AlternateNumber": alternateNumber = value
            case "AlternateSeries": alternateSeries = value
            case "Day": day = Int(value)
            case "GTIN": gtin = value
            case "Genre": genres = value.splitComma()
            case "Imprint": imprint = value
            case "LanguageISO": languageISO = value
            case "Manga": manga = Manga(rawValue: value)
            case "Month": month = Int(value)
            case "Number": number = value
            case "Publisher": publisher = value
            case "Series": series = value
            case "Summary": summary = value
            case "Title": title = value
            case "Year": year = Int(value)

            // Contributors
            case "Colorist": colorists = value.splitComma()
            case "CoverArtist": coverArtists = value.splitComma()
            case "Editor": editors = value.splitComma()
            case "Inker": inkers = value.splitComma()
            case "Letterer": letterers = value.splitComma()
            case "Penciller": pencillers = value.splitComma()
            case "Translator": translators = value.splitComma()
            case "Writer": writers = value.splitComma()

            // Everything else goes to otherMetadata
            default: otherMetadata[tag] = value
            }
        }
    }

    /// Converts to RWPM Metadata.
    func toMetadata() -> Metadata {
        // Build published date from year/month/day
        var published: Date?
        if let year = year {
            var components = DateComponents()
            components.year = year
            components.month = month ?? 1
            components.day = day ?? 1
            published = Calendar(identifier: .gregorian).date(from: components)
        }

        // Parse series
        var belongsToSeries: [Contributor] = []
        if let series = series {
            let position = number.flatMap { Double($0) }
            belongsToSeries.append(Contributor(name: series, position: position))
        }
        if let alternateSeries = alternateSeries {
            let position = alternateNumber.flatMap { Double($0) }
            belongsToSeries.append(Contributor(name: alternateSeries, position: position))
        }

        // Build other metadata with specification URL prefix
        var rwpmOtherMetadata: [String: Any] = [:]
        for (key, value) in otherMetadata {
            rwpmOtherMetadata[Self.otherMetadataPrefix + key.lowercased()] = value
        }

        return Metadata(
            identifier: gtin,
            title: title,
            published: published,
            languages: languageISO.map { [$0] } ?? [],
            subjects: genres.map { Subject(name: $0) },
            authors: writers.map { Contributor(name: $0) },
            translators: translators.map { Contributor(name: $0) },
            editors: editors.map { Contributor(name: $0) },
            letterers: letterers.map { Contributor(name: $0) },
            pencilers: pencillers.map { Contributor(name: $0) },
            colorists: colorists.map { Contributor(name: $0) },
            inkers: inkers.map { Contributor(name: $0) },
            contributors: coverArtists.map { Contributor(name: $0, role: "cov") },
            publishers: publisher.map { [Contributor(name: $0)] } ?? [],
            imprints: imprint.map { [Contributor(name: $0)] } ?? [],
            readingProgression: (manga == .yesAndRightToLeft) ? .rtl : .auto,
            description: summary,
            belongsToSeries: belongsToSeries,
            otherMetadata: rwpmOtherMetadata
        )
    }

    // MARK: - ComicInfo Types

    /// Page type values from the ComicInfo specification.
    ///
    /// See: https://anansi-project.github.io/docs/comicinfo/documentation#type
    enum PageType: Hashable, Sendable {
        case frontCover
        case innerCover
        case roundup
        case story
        case advertisement
        case editorial
        case letters
        case preview
        case backCover
        case other
        case deleted

        /// Case-insensitive initializer.
        init?(rawValue: String) {
            switch rawValue.lowercased() {
            case "frontcover": self = .frontCover
            case "innercover": self = .innerCover
            case "roundup": self = .roundup
            case "story": self = .story
            case "advertisement": self = .advertisement
            case "editorial": self = .editorial
            case "letters": self = .letters
            case "preview": self = .preview
            case "backcover": self = .backCover
            case "other": self = .other
            case "deleted", "delete": self = .deleted
            default: return nil
            }
        }
    }

    /// Information about a single page from ComicInfo.xml.
    ///
    /// See: https://anansi-project.github.io/docs/comicinfo/documentation#pages--comicpageinfo
    struct PageInfo: Hashable, Sendable {
        /// Zero-based index of this page in the reading order.
        let image: Int

        /// The type/purpose of this page.
        let type: PageType?

        /// Whether this is a double-page spread.
        let doublePage: Bool?

        /// File size in bytes.
        let imageSize: Int64?

        /// Page key/identifier.
        let key: String?

        /// Bookmark name for this page.
        let bookmark: String?

        /// Width of the page image in pixels.
        let imageWidth: Int?

        /// Height of the page image in pixels.
        let imageHeight: Int?

        /// Parses a PageInfo from an XML <Page> element.
        init?(element: ReadiumFuzi.XMLElement) {
            guard
                let imageStr = element.attr("Image"),
                let image = Int(imageStr)
            else {
                return nil
            }

            self.image = image
            type = element.attr("Type").flatMap { PageType(rawValue: $0) }
            doublePage = element.attr("DoublePage").flatMap {
                switch $0.lowercased() {
                case "true", "1": return true
                case "false", "0": return false
                default: return nil
                }
            }
            imageSize = element.attr("ImageSize").flatMap { Int64($0) }
            key = element.attr("Key")
            bookmark = element.attr("Bookmark")
            imageWidth = element.attr("ImageWidth").flatMap { Int($0) }
            imageHeight = element.attr("ImageHeight").flatMap { Int($0) }
        }
    }

    /// Manga field values indicating whether the book is a manga and its
    /// reading direction.
    ///
    /// See: https://anansi-project.github.io/docs/comicinfo/documentation#manga
    enum Manga {
        case unknown
        case no
        case yes
        case yesAndRightToLeft

        /// Case-insensitive initializer.
        init?(rawValue: String) {
            switch rawValue.lowercased() {
            case "unknown": self = .unknown
            case "no": self = .no
            case "yes": self = .yes
            case "yesandrighttoleft": self = .yesAndRightToLeft
            default: return nil
            }
        }
    }
}

private extension String {
    func splitComma() -> [String] {
        split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
