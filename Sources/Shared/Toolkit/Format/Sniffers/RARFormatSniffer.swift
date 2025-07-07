//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs a RAR file.
public struct RARFormatSniffer: FormatSniffer {
    public init() {}

    public func sniffHints(_ hints: FormatHints) -> Format? {
        if
            hints.hasFileExtension("rar") ||
            hints.hasMediaType("application/vnd.rar", "application/x-rar", "application/x-rar-compressed")
        {
            return rar
        }

        return nil
    }

    public func sniffBlob(_ blob: FormatSnifferBlob, refining format: Format) async -> ReadResult<Format?> {
        // https://en.wikipedia.org/wiki/List_of_file_signatures
        await blob.read(range: 0 ..< 8)
            .map { data in
                guard
                    data.count > 8,
                    data[0 ..< 7] == Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00]) ||
                    data == Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00])
                else {
                    return nil
                }
                return rar
            }
    }

    private let rar = Format(
        specifications: .rar,
        mediaType: .rar,
        fileExtension: "rar"
    )
}
