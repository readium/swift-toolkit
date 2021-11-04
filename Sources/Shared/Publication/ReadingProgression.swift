//
//  ReadingProgression.swift
//  r2-shared-swift
//
//  Created by Mickaël on 24/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public enum ReadingProgression: String {
    /// Left to right
    case ltr
    /// Right to left
    case rtl
    /// Top to bottom
    case ttb
    /// Bottom to top
    case btt
    case auto
    
    /// Returns the leading Page for the reading progression.
    public var leadingPage: Presentation.Page {
        switch self {
        case .ltr, .ttb, .auto:
            return .left
        case .rtl, .btt:
            return .right
        }
    }
}
