//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Access a License Document stored in an EPUB archive, under META-INF/license.lcpl.
final class EPUBLicenseContainer: ZIPLicenseContainer {
    init(epub: URL) {
        super.init(zip: epub, pathInZIP: "META-INF/license.lcpl")
    }
}
