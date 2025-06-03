//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared

extension LinkRelation {
    init?(epubType: String) {
        switch epubType {
        case "cover":
            self = .cover
        case "toc":
            self = .contents
        case "bodymatter":
            self = .start
        default:
            return nil
        }
    }
}
