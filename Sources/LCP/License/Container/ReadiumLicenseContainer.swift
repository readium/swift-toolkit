//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Access a License Document stored in a webpub, audiobook or LCPDF package.
final class ReadiumLicenseContainer: ZIPLicenseContainer {
    init(path: URL) {
        super.init(zip: path, pathInZIP: "license.lcpl")
    }
}
