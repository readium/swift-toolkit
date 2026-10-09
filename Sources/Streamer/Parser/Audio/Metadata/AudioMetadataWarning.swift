//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Warning raised when reading the metadata of the audio files of a
/// publication.
public enum AudioMetadataWarning: Warning, Hashable {
    /// The ISBN of the audio file at `href` is not a valid ISBN-10 or ISBN-13.
    /// It was ignored.
    case invalidISBN(href: AnyURL, isbn: String)

    /// A chapter of the audio file at `href` has a start time which is
    /// negative or not finite. It was left out of the table of contents.
    case invalidChapterStart(href: AnyURL, title: String)

    /// The metadata of the audio file at `href` could not be interpreted. The
    /// file was kept in the reading order without its metadata.
    case undecodableMetadata(href: AnyURL, reason: String)

    public var tag: String {
        "audio-metadata"
    }

    public var message: String {
        switch self {
        case let .invalidISBN(href: href, isbn: isbn):
            return "Ignored the invalid ISBN `\(isbn)` of \(href.string)"
        case let .invalidChapterStart(href: href, title: title):
            return "Ignored the chapter `\(title)` of \(href.string), its start time is invalid"
        case let .undecodableMetadata(href: href, reason: reason):
            return "Ignored the metadata of \(href.string), it could not be read: \(reason)"
        }
    }

    public var severity: WarningSeverityLevel {
        .minor
    }
}
