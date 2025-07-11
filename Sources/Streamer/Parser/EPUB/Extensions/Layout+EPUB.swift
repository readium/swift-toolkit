//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

extension Layout {
    /// Creates from an EPUB rendition:layout property.
    init?(epub: String) {
        switch epub {
        case "reflowable":
            self = .reflowable
        case "pre-paginated":
            self = .fixed
        default:
            return nil
        }
    }
}
