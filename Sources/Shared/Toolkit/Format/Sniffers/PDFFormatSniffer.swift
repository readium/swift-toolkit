//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs a PDF document.
///
/// Reference: https://www.loc.gov/preservation/digital/formats/fdd/fdd000123.shtml
public struct PDFFormatSniffer: FormatSniffer {
    public init() {}

    public func sniffHints(_ hints: FormatHints) -> Format? {
        if
            hints.hasFileExtension("pdf") ||
            hints.hasMediaType("application/pdf")
        {
            return pdf
        }

        return nil
    }

    public func sniffBlob(_ blob: FormatSnifferBlob, refining format: Format) async -> ReadResult<Format?> {
        // https://en.wikipedia.org/wiki/List_of_file_signatures
        await blob.read(range: 0 ..< 5)
            .map { data in
                guard String(data: data, encoding: .utf8) == "%PDF-" else {
                    return nil
                }
                return pdf
            }
    }

    private let pdf = Format(
        specifications: .pdf,
        mediaType: .pdf,
        fileExtension: "pdf"
    )
}
