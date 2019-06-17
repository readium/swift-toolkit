//
//  R2NavigatorLocalizedString.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 14.06.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

func R2NavigatorLocalizedString(_ key: String, _ values: CVarArg...) -> String {
    return R2LocalizedString("R2Navigator.\(key)", in: "org.readium.r2-navigator-swift", values)
}
