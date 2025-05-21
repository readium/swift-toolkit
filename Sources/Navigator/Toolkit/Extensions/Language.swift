//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

extension Language {
    var isRTL: Bool {
        let c = code.bcp47.lowercased()
        return c == "ar"
            || c == "fa"
            || c == "he"
            || c == "zh-hant"
            || c == "zh-tw"
    }

    var isCJK: Bool {
        let c = code.bcp47.lowercased()
        return c == "ja"
            || c == "ko"
            || removingRegion().code.bcp47.lowercased() == "zh"
    }
}
