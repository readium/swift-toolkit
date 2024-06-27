//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs an EPUB publication.
public struct EPUBFormatSniffer: FormatSniffer {
    public func sniffHints(_ hints: FormatHints) -> Format? {
        if
            hints.hasFileExtension("epub") ||
            hints.hasMediaType("application/epub+zip")
        {
            return epub
        }

        return nil
    }

    public func sniffContainer<C>(_ container: C, refining format: Format) async -> ReadResult<Format> where C : Container {
        return .success(.null)
    }

    private let epub = Format(
        specifications: .zip, .epub,
        mediaType: .epub,
        fileExtension: "epub"
    )
}
