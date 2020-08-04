//
//  ContentLayout+EPUB.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 01/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

extension ContentLayout {
    
    var userSettingsPreset: [ReadiumCSSName: Bool] {
        switch self {
        case .rtl:
            return [
                .hyphens: false,
                .wordSpacing: false,
                .letterSpacing: false,
                .ligatures: true
            ]
            
        case .ltr:
            return [
                .hyphens: false,
                .ligatures: false
            ]
            
        case .cjkVertical:
            return [
                .scroll: true,
                .columnCount: false,
                .textAlignment: false,
                .hyphens: false,
                .paraIndent: false,
                .wordSpacing: false,
                .letterSpacing: false
            ]
            
        case .cjkHorizontal:
            return [
                .textAlignment: false,
                .hyphens: false,
                .paraIndent: false,
                .wordSpacing: false,
                .letterSpacing: false
            ]
        }
    }
    
}
