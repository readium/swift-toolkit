//
//  UserSettings.swift
//  r2-shared-swift
//
//  Created by Geoffrey Bugniot, Mickaël Menu on 14.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// List of strings that can identify a user setting
public enum ReadiumCSSReference: String {
    case fontSize           = "fontSize"
    case fontFamily         = "fontFamily"
    case fontOverride       = "fontOverride"
    case appearance         = "appearance"
    case scroll             = "scroll"
    case publisherDefault   = "advancedSettings"
    case textAlignment      = "textAlign"
    case columnCount        = "colCount"
    case wordSpacing        = "wordSpacing"
    case letterSpacing      = "letterSpacing"
    case pageMargins        = "pageMargins"
    case lineHeight         = "lineHeight"
    case paraIndent         = "paraIndent"
    case hyphens            = "bodyHyphens"
    case ligatures          = "ligatures"
}

/// List of strings that can identify the name of a CSS custom property
/// Also used for storing UserSettings in UserDefaults
public enum ReadiumCSSName: String {
    case fontSize           = "--USER__fontSize"
    case fontFamily         = "--USER__fontFamily"
    case fontOverride       = "--USER__fontOverride"
    case appearance         = "--USER__appearance"
    case scroll             = "--USER__scroll"
    case publisherDefault   = "--USER__advancedSettings"
    case textAlignment      = "--USER__textAlign"
    case columnCount        = "--USER__colCount"
    case wordSpacing        = "--USER__wordSpacing"
    case letterSpacing      = "--USER__letterSpacing"
    case pageMargins        = "--USER__pageMargins"
    case lineHeight         = "--USER__lineHeight"
    case paraIndent         = "--USER__paraIndent"
    case hyphens            = "--USER__bodyHyphens"
    case ligatures          = "--USER__ligatures"
}
