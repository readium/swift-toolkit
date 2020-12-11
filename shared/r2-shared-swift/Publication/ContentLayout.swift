//
//  ContentLayout.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri, Mickaël Menu on 13.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

@available(*, deprecated, message: "Use `publication.metadata.effectiveReadingProgression` instead")
public enum ContentLayout: String {
    case rtl = "rtl"
    case ltr = "ltr"
    case cjkVertical = "cjk-vertical"
    case cjkHorizontal = "cjk-horizontal"
    
    @available(*, unavailable, message: "Use `publication.metadata.effectiveReadingProgression` instead", renamed: "metadata.effectiveReadingProgression")
    public var readingProgression: ReadingProgression {
        switch self {
        case .rtl, .cjkVertical:
            return .rtl
        case .ltr, .cjkHorizontal:
            return .ltr
        }
    }

}
