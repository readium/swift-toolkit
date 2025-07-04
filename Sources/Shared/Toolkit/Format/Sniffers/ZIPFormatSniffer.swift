//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs a ZIP file.
public struct ZIPFormatSniffer: FormatSniffer {
    public init() {}

    public func sniffHints(_ hints: FormatHints) -> Format? {
        if
            hints.hasFileExtension("zip") ||
            hints.hasMediaType("application/zip")
        {
            return zip
        }

        return nil
    }

    public func sniffBlob(_ blob: FormatSnifferBlob, refining format: Format) async -> ReadResult<Format?> {
        // https://en.wikipedia.org/wiki/List_of_file_signatures
        await blob.read(range: 0 ..< 4)
            .map { data in
                guard
                    data == Data([0x50, 0x4B, 0x03, 0x04]) ||
                    data == Data([0x50, 0x4B, 0x05, 0x06]) ||
                    data == Data([0x50, 0x4B, 0x07, 0x08])
                else {
                    return nil
                }
                return zip
            }
    }

    private let zip = Format(
        specifications: .zip,
        mediaType: .zip,
        fileExtension: "zip"
    )
}
