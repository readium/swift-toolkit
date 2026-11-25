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
        tag == "zh-Hant" || tag == "zh-TW" || ["ar", "fa", "he"].contains(code)
    }

    /// Whether this is a Chinese, Japanese or Korean language, which can be
    /// laid out horizontally or vertically.
    ///
    /// See https://github.com/readium/css/blob/develop/css/dist/ReadMe.md#cjk
    var isCJK: Bool {
        ["zh", "ja", "ko"].contains(code)
    }
}
