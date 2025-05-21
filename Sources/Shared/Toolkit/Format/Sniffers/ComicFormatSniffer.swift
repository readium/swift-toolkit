//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs a ComicBook Archive.
public struct ComicFormatSniffer: FormatSniffer {
    /// Required extensions for an archive to be considered a ComicBook Archive.
    /// Reference: https://wiki.mobileread.com/wiki/CBR_and_CBZ
    public static let defaultRequiredExtensions: Set<FileExtension> = bitmapExtensions

    /// Additional extensions authorized in a ComicBook Archive.
    public static let defaultAllowedExtensions: Set<FileExtension> = ["acbf", "xml"]

    private static let bitmapExtensions: Set<FileExtension> = [
        "avif",
        "bmp",
        "dib",
        "gif",
        "jif",
        "jfi",
        "jfif",
        "jpg",
        "jpeg",
        "png",
        "tif",
        "tiff",
        "webp",
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
            hints.hasFileExtension("cbz") ||
            hints.hasMediaType("application/vnd.comicbook+zip", "application/x-cbz")
        {
            return Format(
                specifications: .zip, .informalComic,
                mediaType: .cbz,
                fileExtension: "cbz"
            )
        }

        if
            hints.hasFileExtension("cbr") ||
            hints.hasMediaType("application/vnd.comicbook-rar", "application/x-cbr")
        {
            return Format(
                specifications: .rar, .informalComic,
                mediaType: .cbr,
                fileExtension: "cbr"
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
        format.addSpecifications(.informalComic)

        if format.conformsTo(.zip) {
            format.mediaType = .cbz
            format.fileExtension = "cbz"
        } else if format.conformsTo(.rar) {
            format.mediaType = .cbr
            format.fileExtension = "cbr"
        }

        return .success(format)
    }
}
