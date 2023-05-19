//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// List of strings that can identify a user setting
public enum ReadiumCSSReference: String {
    case fontSize
    case fontFamily
    case fontOverride
    case appearance
    case scroll
    case publisherDefault = "advancedSettings"
    case textAlignment = "textAlign"
    case columnCount = "colCount"
    case wordSpacing
    case letterSpacing
    case pageMargins
    case lineHeight
    case paraIndent
    case hyphens = "bodyHyphens"
    case ligatures
    case paragraphMargins
    case textColor
    case backgroundColor
}

/// List of strings that can identify the name of a CSS custom property
/// Also used for storing UserSettings in UserDefaults
public enum ReadiumCSSName: String {
    case fontSize = "--USER__fontSize"
    case fontFamily = "--USER__fontFamily"
    case fontOverride = "--USER__fontOverride"
    case appearance = "--USER__appearance"
    case scroll = "--USER__scroll"
    case publisherDefault = "--USER__advancedSettings"
    case textAlignment = "--USER__textAlign"
    case columnCount = "--USER__colCount"
    case wordSpacing = "--USER__wordSpacing"
    case letterSpacing = "--USER__letterSpacing"
    case pageMargins = "--USER__pageMargins"
    case lineHeight = "--USER__lineHeight"
    case paraIndent = "--USER__paraIndent"
    case hyphens = "--USER__bodyHyphens"
    case ligatures = "--USER__ligatures"
    case paragraphMargins = "--USER__paraSpacing"
    case textColor = "--USER__textColor"
    case backgroundColor = "--USER__backgroundColor"
}
