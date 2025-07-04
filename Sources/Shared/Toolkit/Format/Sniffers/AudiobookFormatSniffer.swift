//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs an Audiobook.
public struct ZABFormatSniffer: FormatSniffer {
    /// Required extensions for an archive to be considered an audiobook
    public static let defaultRequiredExtensions: Set<FileExtension> = audioExtensions

    /// Additional extensions authorized in an Audiobook.
    public static let defaultAllowedExtensions: Set<FileExtension> = playlistExtensions

    private static let audioExtensions: Set<FileExtension> = [
        "aac",
        "aiff",
        "alac",
        "flac",
        "m4a",
        "m4b",
        "mp3",
        "ogg",
        "oga",
        "mogg",
        "opus",
        "wav",
        "webm",
    ]

    private static let playlistExtensions: Set<FileExtension> = [
        "asx",
        "bio",
        "m3u",
        "m3u8",
        "pla",
        "pls",
        "smil",
        "vlc",
        "wpl",
        "xspf",
        "zpl",
    ]

    private let requiredExtensions: Set<FileExtension>
    private let allowedExtensions: Set<FileExtension>

    public init(
        requiredExtensions: Set<FileExtension> = Self.defaultRequiredExtensions,
        allowedExtensions: Set<FileExtension> = Self.defaultAllowedExtensions
    ) {
        self.requiredExtensions = requiredExtensions
        self.allowedExtensions = requiredExtensions.union(allowedExtensions)
    }

    public func sniffHints(_ hints: FormatHints) -> Format? {
        if
            hints.hasFileExtension("zab") ||
            hints.hasMediaType("application/x.readium.zab+zip")
        {
            return Format(
                specifications: .zip, .informalAudiobook,
                mediaType: .zab,
                fileExtension: "zab"
            )
        }

        return nil
    }

    public func sniffContainer<C>(_ container: C, refining format: Format) async -> ReadResult<Format?> where C: Container {
        let entries = container.entries
            .filter {
                $0.lastPathSegment?.hasPrefix(".") == false &&
                    $0.lastPathSegment != "Thumbs.db"
            }
        let containerExtensions = Set(entries.compactMap(\.pathExtension))
        guard
            !containerExtensions.isEmpty,
            allowedExtensions.isSuperset(of: containerExtensions),
            containerExtensions.contains(where: { requiredExtensions.contains($0) })
        else {
            return .success(nil)
        }

        var format = format
        format.addSpecifications(.informalAudiobook)

        if format.conformsTo(.zip) {
            format.mediaType = .zab
            format.fileExtension = "zab"
        }

        return .success(format)
    }
}
