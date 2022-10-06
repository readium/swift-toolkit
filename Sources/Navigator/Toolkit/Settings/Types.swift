//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public enum Axis: String {
    case horizontal
    case vertical
}

/// Indicates the condition to be met for the publication to be rendered within a synthetic spread.
public enum Spread: String {
    /// The publication should be displayed in a spread if the screen is large enough.
    case auto
    /// The publication should never be displayed in a spread.
    case never
    /// The publication should always be displayed in a spread.
    case always
}
