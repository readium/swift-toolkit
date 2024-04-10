//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

extension RelativeURL {
    /// According to the EPUB specification, the HREFs in the EPUB package must
    /// be valid URLs (so percent-encoded). Unfortunately, many EPUBs don't
    /// follow this rule, and use invalid HREFs such as `﻿my chapter.html`
    /// or ﻿`/dir/my chapter.html`.
    ///
    /// As a workaround, we assume the HREFs are valid percent-encoded URLs,
    /// and fallback to decoded paths if we can't parse the URL.
    init?(epubHREF: String) {
        guard let uri = RelativeURL(string: epubHREF) ?? RelativeURL(path: epubHREF) else {
            return nil
        }
        self = uri
    }
}
