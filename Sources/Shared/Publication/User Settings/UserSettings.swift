//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// List of strings that can identify a user setting
@available(*, unavailable, message: "Take a look at the migration guide to migrate to the new Preferences API")
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
