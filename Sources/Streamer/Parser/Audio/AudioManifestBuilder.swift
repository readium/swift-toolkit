//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Builds the manifest of an audio publication from the metadata of its audio
/// files.
///
/// https://github.com/readium/architecture/blob/master/streamer/parser/audio-metadata.md#aggregation
struct AudioManifestBuilder {
    /// An audio file of the publication.
    struct Entry {
        let url: AnyURL
        let format: Format

        /// Metadata of the file, or nil when it was not read.
        let metadata: AudioMetadata?
    }

    /// Builds the manifest from the given audio files, in reading order.
    func build(entries: [Entry], warnings: WarningLogger?) -> Manifest {
        let files = entries.compactMap(\.metadata)

        return Manifest(
            metadata: Metadata(
                identifier: makeIdentifier(entries: entries, warnings: warnings),
                conformsTo: [.audiobook],
                title: files.firstNonBlank(of: [\.album, \.title]),
                subtitle: files.firstNonBlank(of: [\.subtitle]),
                published: files.first(of: [\.releaseDate, \.date]),
                languages: files.values(of: [\.languages]),
                sortAs: files.firstNonBlank(of: [\.sortAlbum, \.sortTitle]),
                subjects: files.values(of: [\.genres]).map { Subject(name: $0) },
                authors: files.values(of: [\.albumArtists, \.artists]).map { Contributor(name: $0) },
                narrators: files.values(of: [\.narrators, \.composers]).map { Contributor(name: $0) },
                publishers: files.values(of: [\.publishers]).map { Contributor(name: $0) },
                description: files.firstNonBlank(of: [\.description, \.summary, \.comment]),
                duration: makeDuration(entries: entries),
                belongsToSeries: files.series
            ),
            readingOrder: entries.map { entry in
                Link(
                    href: entry.url.string,
                    mediaType: entry.format.mediaType,
                    title: entry.metadata?.title?.orNilIfBlank(),
                    bitrate: entry.metadata?.bitrate?.orNilIfNotPositive(),
                    duration: entry.metadata?.duration?.orNilIfNotPositive()
                )
            },
            tableOfContents: makeTableOfContents(entries: entries, warnings: warnings)
        )
    }

    /// Returns the URN of the first valid ISBN, following the reading order.
    private func makeIdentifier(entries: [Entry], warnings: WarningLogger?) -> String? {
        var identifier: String?
        var invalidISBNs = Set<String>()

        for entry in entries {
            guard let isbn = entry.metadata?.isbn?.orNilIfBlank() else {
                continue
            }

            if let isbn = ISBN(rawValue: isbn) {
                identifier = identifier ?? isbn.urn
            } else if invalidISBNs.insert(isbn).inserted {
                warnings?.log(AudioMetadataWarning.invalidISBN(href: entry.url, isbn: isbn))
            }
        }

        return identifier
    }

    /// Returns the sum of the file durations, or nil when the duration of a
    /// file is unknown or when there is no file.
    private func makeDuration(entries: [Entry]) -> TimeInterval? {
        var total: TimeInterval = 0
        for entry in entries {
            guard let duration = entry.metadata?.duration?.orNilIfNotPositive() else {
                return nil
            }
            total += duration
        }
        return total.orNilIfNotPositive()
    }

    /// Returns the concatenation of the chapters of each file, or an empty
    /// list when no file has a titled chapter.
    ///
    /// https://github.com/readium/architecture/blob/master/streamer/parser/audio-metadata.md#table-of-contents
    private func makeTableOfContents(entries: [Entry], warnings: WarningLogger?) -> [Link] {
        let chapters = entries.map { entry in
            makeLinks(for: entry.metadata?.chapters ?? [], of: entry, warnings: warnings)
        }

        guard chapters.contains(where: { !$0.isEmpty }) else {
            return []
        }

        return zip(entries, chapters).flatMap { entry, chapters -> [Link] in
            guard chapters.isEmpty else {
                return chapters
            }

            // A file without any titled chapter contributes one link, unless
            // it has no title either.
            guard let title = entry.metadata?.title?.orNilIfBlank() else {
                return []
            }
            return [
                Link(
                    href: entry.url.string,
                    title: title,
                    duration: entry.metadata?.duration?.orNilIfNotPositive()
                ),
            ]
        }
    }

    /// Returns the links of the given chapters of a file, keeping their order
    /// and their hierarchy.
    ///
    /// A chapter without a title, or with an invalid start time, is left out
    /// and its children take its place.
    private func makeLinks(for chapters: [AudioMetadata.Chapter], of entry: Entry, warnings: WarningLogger?) -> [Link] {
        chapters.flatMap { chapter -> [Link] in
            let children = makeLinks(for: chapter.children, of: entry, warnings: warnings)

            guard let title = chapter.title?.orNilIfBlank() else {
                return children
            }

            guard let position = TemporalPosition(time: chapter.start.roundedToMilliseconds) else {
                warnings?.log(AudioMetadataWarning.invalidChapterStart(href: entry.url, title: title))
                return children
            }

            return [
                Link(
                    href: entry.url.replacingFragment(TemporalSelector.position(position).fragment).string,
                    title: title,
                    duration: chapter.duration?.orNilIfNotPositive(),
                    children: children
                ),
            ]
        }
    }
}

private extension [AudioMetadata] {
    /// Returns the first value of the given sources, listed in priority
    /// order.
    ///
    /// The priority applies across all the files, not inside each file: the
    /// value comes from the first source holding one in any file.
    func first<T>(of sources: [KeyPath<AudioMetadata, T?>]) -> T? {
        for source in sources {
            if let value = lazy.compactMap({ $0[keyPath: source] }).first {
                return value
            }
        }
        return nil
    }

    /// Same as `first(of:)` for strings, ignoring the blank values.
    func firstNonBlank(of sources: [KeyPath<AudioMetadata, String?>]) -> String? {
        values(of: sources).first
    }

    /// Returns the distinct non-blank values of the first of the given
    /// sources holding one in any file, following the reading order.
    func values(of sources: [KeyPath<AudioMetadata, [String]>]) -> [String] {
        values(of: sources) { $0 }
    }

    /// Same as `values(of:)` for sources holding a single value per file.
    func values(of sources: [KeyPath<AudioMetadata, String?>]) -> [String] {
        values(of: sources) { [String](ofNotNil: $0) }
    }

    private func values<T>(of sources: [KeyPath<AudioMetadata, T>], _ strings: (T) -> [String]) -> [String] {
        for source in sources {
            let values = flatMap { strings($0[keyPath: source]) }
                .filter { !$0.isBlank }

            if !values.isEmpty {
                return values.removingDuplicates()
            }
        }
        return []
    }

    /// Series of the publication.
    ///
    /// The position of a series comes from the files carrying its name only:
    /// their first movement index, or else their first series position.
    var series: [Metadata.Collection] {
        values(of: [\.movementName, \.series]).map { name in
            Metadata.Collection(
                name: name,
                position: filter { $0.movementName == name || $0.series == name }
                    .first(of: [\.movementIndex, \.seriesPosition])
            )
        }
    }
}
