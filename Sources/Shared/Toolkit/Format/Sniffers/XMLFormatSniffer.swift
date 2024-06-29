//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs an XML document.
public struct XMLFormatSniffer: FormatSniffer {
    public func sniffHints(_ hints: FormatHints) -> Format? {
        if
            hints.hasFileExtension("xml") ||
            hints.hasMediaType("application/xml", "text/xml")
        {
            return xml
        }

        return nil
    }

    private let xml = Format(
        specifications: .xml,
        mediaType: .xml,
        fileExtension: "xml"
    )
}
