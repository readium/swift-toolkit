//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A simplified view of a publication's metadata.
///
/// Readium's `Metadata` type covers the full Readium Web Publication spec.
/// This struct extracts the fields most useful for a bookshelf or reading app
/// and converts them to their most useful representation (e.g. a String for
/// authors' name).
struct PublicationMetadata {
    // MARK: - About

    /// The title of the publication.
    let title: String?

    /// The subtitle of the publication
    let subtitle: String?

    /// Date of publication.
    let published: Date?

    /// Date of modification.
    let modified: Date?

    /// Language of this publication.
    let language: Language?

    /// Thematic keywords (BISAC, THEMA, etc.)
    let subjects: [String]

    /// Number of pages in a pre-paginated publication.
    let numberOfPages: Int?

    /// Duration in seconds in an audio publication.
    let duration: Duration?

    /// A description for the publication.
    /// Warning: It may contain HTML markup.
    let description: String?

    /// A series groups related volumes in a defined reading order
    /// (e.g. "A Song of Ice and Fire", position 3).
    let series: [String]

    /// Collections are named groupings without an implied reading order
    /// (e.g. a publisher catalogue or award shortlist).
    let collections: [String]

    /// List of contributors grouped by their roles.
    let contributors: Contributors

    /// All contributor roles defined by the Readium Web Publication spec.
    struct Contributors {
        let authors: [String]
        let translators: [String]
        let editors: [String]
        let artists: [String]
        let illustrators: [String]
        let letterers: [String]
        let pencilers: [String]
        let colorists: [String]
        let inkers: [String]
        let narrators: [String]
        let contributors: [String]
        let publishers: [String]
        let imprints: [String]
    }

    // MARK: - Technical

    /// The publication's unique ID — often an ISBN for books or a UUID assigned
    /// by the authoring tool.
    ///
    /// For an EPUB, this is sourced from `dc:identifier`.
    let identifier: String?

    /// A URI declaring which Readium Web Publication profile this publication
    /// conforms to (e.g. `https://readium.org/webpub-manifest/profiles/epub`).
    /// The profile determines which navigator and features apply.
    let profiles: [Publication.Profile]

    /// Presentation mode for the content.
    ///
    /// - **reflowable** text reflows to the screen size (typical for novels)
    /// - **fixed** layout preserves exact page geometry (picture books, comics,
    ///   or complex designs).
    /// - **scrolled** displays in a continuous scroll (web toons)
    let layout: Layout?
}

/// Extracts a simplified metadata view from an opened publication.
func readMetadata(of publication: Publication) -> PublicationMetadata {
    let m = publication.metadata

    /// Contributors can have a display name different from the sort name. For
    /// example, "Albert Camus" could be sorted as "Camus, Albert".
    func names(_ contributors: [Contributor]) -> [String] {
        contributors
            .sorted { ($0.sortAs ?? $0.name) < ($1.sortAs ?? $1.name) }
            .map(\.name)
    }

    /// Subjects can also be sorted using a different sort name.
    func subjects(_ src: [Subject]) -> [String] {
        src
            .sorted { ($0.sortAs ?? $0.name) < ($1.sortAs ?? $1.name) }
            .map(\.name)
    }

    /// Series and collections can also be sorted using a different sort name.
    ///
    /// They can also have a position that determines the reading-order of the
    /// series. In this example, we will format the book 5 of A Song of Ice and
    /// Fire as "A Song of Ice and Fire (5)"
    func collections(_ src: [Metadata.Collection]) -> [String] {
        src
            .sorted { ($0.sortAs ?? $0.name) < ($1.sortAs ?? $1.name) }
            .map {
                var name = $0.name
                if let position = $0.position {
                    name += " (\(position.formatted(.number)))"
                }
                return name
            }
    }

    return PublicationMetadata(
        title: m.title,
        subtitle: m.subtitle,
        published: m.published,
        modified: m.modified,
        language: m.language,
        subjects: subjects(m.subjects),
        numberOfPages: m.numberOfPages,
        duration: m.duration.map { Duration.seconds($0) },
        description: m.description,
        series: collections(m.belongsToSeries),
        collections: collections(m.belongsToCollections),
        contributors: .init(
            authors: names(m.authors),
            translators: names(m.translators),
            editors: names(m.editors),
            artists: names(m.artists),
            illustrators: names(m.illustrators),
            letterers: names(m.letterers),
            pencilers: names(m.pencilers),
            colorists: names(m.colorists),
            inkers: names(m.inkers),
            narrators: names(m.narrators),
            contributors: names(m.contributors),
            publishers: names(m.publishers),
            imprints: names(m.imprints)
        ),
        identifier: m.identifier,
        profiles: publication.manifest.metadata.conformsTo,
        layout: m.layout
    )
}
