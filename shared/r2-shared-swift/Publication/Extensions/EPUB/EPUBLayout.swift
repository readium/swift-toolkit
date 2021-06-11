//
//  EPUBLayout.swift
//  r2-shared-swift
//
//  Created by Mickaël on 24/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Hint about the nature of the layout for the linked resources.
public enum EPUBLayout: String {
    case fixed, reflowable
}
