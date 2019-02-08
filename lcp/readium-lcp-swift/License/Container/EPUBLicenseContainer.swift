//
//  EPUBLicenseContainer.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 05.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Access a License Document stored in an EPUB archive, under META-INF/license.lcpl.
final class EPUBLicenseContainer: ZIPLicenseContainer {
    
    init(epub: URL) {
        super.init(zip: epub, pathInZIP: "META-INF/license.lcpl")
    }
    
}
