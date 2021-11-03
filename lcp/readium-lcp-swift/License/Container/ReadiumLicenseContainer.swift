//
//  ReadiumLicenseContainer.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 18.06.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Access a License Document stored in a webpub, audiobook or LCPDF package.
final class ReadiumLicenseContainer: ZIPLicenseContainer {
    
    init(path: URL) {
        super.init(zip: path, pathInZIP: "license.lcpl")
    }
    
}
