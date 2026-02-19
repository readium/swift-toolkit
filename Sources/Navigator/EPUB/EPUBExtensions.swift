//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared

internal extension Metadata {
    var epubLayout: EPUBLayout {
        layout == .fixed ? .fixed : .reflowable
    }
}
