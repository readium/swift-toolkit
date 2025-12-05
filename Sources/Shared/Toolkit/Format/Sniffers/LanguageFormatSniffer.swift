//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public class LanguageFormatSniffer: FormatSniffer {
    public init() {}

    public func sniffHints(_ hints: FormatHints) -> Format? {
        // JavaScript
        if
            hints.hasMediaType("text/javascript", "application/javascript") ||
            hints.hasFileExtension("js")
        {
            return Format(specifications: .javascript, mediaType: .javascript, fileExtension: "js")
        }

        // CSS
        if
            hints.hasMediaType("text/css") ||
            hints.hasFileExtension("css")
        {
            return Format(specifications: .css, mediaType: .css, fileExtension: "css")
        }

        return nil
    }
}
