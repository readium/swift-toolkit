//
//  R2LCPLocalizedString.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 13.06.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

func R2LCPLocalizedString(_ key: String, _ values: CVarArg...) -> String {
    return R2LocalizedString("ReadiumLCP.\(key)", in: "org.readium.readium-lcp-swift", values)
}
