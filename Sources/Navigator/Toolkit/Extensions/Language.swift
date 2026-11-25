//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

extension Language {
    /// Whether publications in this language are read from right to left by
    /// default.
    ///
    /// This is the case of Arabic, Persian and Hebrew whatever their region
    /// or script, and of Traditional Chinese tagged exactly `zh-Hant` or
    /// `zh-TW`, which is laid out vertically.
    ///
    /// See https://github.com/readium/css/blob/develop/docs/CSS16-internationalization.md#missing-page-progression-direction
    var isRTL: Bool {
        let tag = normalizedTag
        if tag == "zh-hant" || tag == "zh-tw" {
            return true
        }
        return ["ar", "fa", "he"].contains(primarySubtag(of: tag))
    }

    /// Whether this is a Chinese, Japanese or Korean language, which can be
    /// laid out horizontally or vertically.
    ///
    /// See https://github.com/readium/css/blob/develop/css/dist/ReadMe.md#cjk
    var isCJK: Bool {
        ["zh", "ja", "ko"].contains(primarySubtag(of: normalizedTag))
    }

    /// Lowercased BCP 47 tag separated with `-`.
    ///
    /// `Locale` identifiers use `_` and can end with keywords, e.g.
    /// `zh_TW@calendar=roc`.
    private var normalizedTag: String {
        code.bcp47
            .prefix { $0 != "@" }
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
    }

    private func primarySubtag(of tag: String) -> Substring {
        tag.prefix { $0 != "-" }
    }
}
