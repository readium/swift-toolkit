//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Metadata read from one audio file: tags, duration, chapters and cover.
///
/// The tags are format-neutral and their values are decoded, but their roles
/// are not resolved.
///
/// The doc comment of each tag gives its source as an MP4 atom, then as an
/// ID3v2 frame.
///
/// https://github.com/readium/architecture/blob/master/streamer/parser/audio-metadata.md
public struct AudioMetadata: Sendable, Hashable {
    /// A titled time range inside an audio file.
    ///
    /// https://github.com/readium/architecture/blob/master/streamer/parser/audio-metadata.md#chapters
    public struct Chapter: Sendable, Hashable {
        public var title: String?

        /// Start time in seconds, from the beginning of the file.
        public var start: TimeInterval

        /// Duration in seconds.
        public var duration: TimeInterval?

        /// Chapters nested in this one, such as the hierarchy an ID3 `CTOC`
        /// frame declares.
        public var children: [Chapter]

        public init(
            title: String? = nil,
            start: TimeInterval,
            duration: TimeInterval? = nil,
            children: [Chapter] = []
        ) {
            self.title = title
            self.start = start
            self.duration = duration
            self.children = children
        }
    }

    /// A cover image embedded in an audio file.
    public struct Cover: Sendable, Hashable {
        /// Encoded bytes of the image.
        public var data: Data

        /// Media type declared by the file for `data`.
        public var mediaType: MediaType?

        public init(data: Data, mediaType: MediaType? = nil) {
            self.data = data
            self.mediaType = mediaType
        }
    }

    /// `©nam`, `TIT2`
    public var title: String?

    /// `©alb`, `TALB`
    public var album: String?

    /// `©st3` then `----:SUBTITLE`, `TIT3`
    public var subtitle: String?

    /// `aART`, `TPE2`
    public var albumArtists: [String]

    /// `©ART`, `TPE1`
    public var artists: [String]

    /// `©nrt`, `TXXX:NARRATOR`
    public var narrators: [String]

    /// `©wrt`, `TCOM`
    public var composers: [String]

    /// `©mvn`, `MVNM`
    public var movementName: String?

    /// `©mvi`, `MVIN`
    public var movementIndex: Double?

    /// `----:SERIES`, `TXXX:SERIES`
    public var series: String?

    /// `----:SERIES-PART`, `TXXX:SERIES-PART`
    public var seriesPosition: Double?

    /// `©pub`, `TPUB`
    public var publishers: [String]

    /// No MP4 atom, `TDRL`
    public var releaseDate: Date?

    /// `©day`, `TDRC` then `TYER`
    public var date: Date?

    /// `©gen` then `gnre`, `TCON`
    public var genres: [String]

    /// `ldes`, `TXXX:DESCRIPTION`
    public var description: String?

    /// `desc`, `TDES`
    public var summary: String?

    /// `©cmt`, `COMM` with an empty description
    public var comment: String?

    /// BCP 47 language tags.
    ///
    /// `----:LANGUAGE`, `TLAN`
    public var languages: [String]

    /// ISBN as written in the file, which may be invalid.
    ///
    /// `----:ISBN`, `TXXX:ISBN`
    public var isbn: String?

    /// `soal`, `TSOA`
    public var sortAlbum: String?

    /// `sonm`, `TSOT`
    public var sortTitle: String?

    /// `covr`, `APIC`
    public var cover: Cover?

    /// Duration of the file in seconds, which may be an estimate.
    public var duration: TimeInterval?

    /// Bitrate of the audio in kbps.
    public var bitrate: Double?

    /// Chapters of the file, ordered by start time.
    ///
    /// QuickTime chapter track then Nero `chpl` atom, `CHAP`
    public var chapters: [Chapter]

    public init(
        title: String? = nil,
        album: String? = nil,
        subtitle: String? = nil,
        albumArtists: [String] = [],
        artists: [String] = [],
        narrators: [String] = [],
        composers: [String] = [],
        movementName: String? = nil,
        movementIndex: Double? = nil,
        series: String? = nil,
        seriesPosition: Double? = nil,
        publishers: [String] = [],
        releaseDate: Date? = nil,
        date: Date? = nil,
        genres: [String] = [],
        description: String? = nil,
        summary: String? = nil,
        comment: String? = nil,
        languages: [String] = [],
        isbn: String? = nil,
        sortAlbum: String? = nil,
        sortTitle: String? = nil,
        cover: Cover? = nil,
        duration: TimeInterval? = nil,
        bitrate: Double? = nil,
        chapters: [Chapter] = []
    ) {
        self.title = title
        self.album = album
        self.subtitle = subtitle
        self.albumArtists = albumArtists
        self.artists = artists
        self.narrators = narrators
        self.composers = composers
        self.movementName = movementName
        self.movementIndex = movementIndex
        self.series = series
        self.seriesPosition = seriesPosition
        self.publishers = publishers
        self.releaseDate = releaseDate
        self.date = date
        self.genres = genres
        self.description = description
        self.summary = summary
        self.comment = comment
        self.languages = languages
        self.isbn = isbn
        self.sortAlbum = sortAlbum
        self.sortTitle = sortTitle
        self.cover = cover
        self.duration = duration
        self.bitrate = bitrate
        self.chapters = chapters
    }
}
