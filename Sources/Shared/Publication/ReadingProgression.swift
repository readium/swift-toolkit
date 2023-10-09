//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
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
