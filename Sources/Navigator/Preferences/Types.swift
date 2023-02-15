//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Layout axis.
public enum Axis: String, Hashable {
    case horizontal
    case vertical
}

/// Synthetic spread policy.
public enum Spread: String, Hashable {
    /// The publication should be displayed in a spread if the screen is large
    /// enough.
    case auto
    /// The publication should never be displayed in a spread.
    case never
    /// The publication should always be displayed in a spread.
    case always
}

/// Direction of the reading progression across resources.
public enum ReadingProgression: String, Hashable {
    case ltr
    case rtl

    public init?(_ readingProgression: R2Shared.ReadingProgression) {
        switch readingProgression {
            case .ltr: self = .ltr
            case .rtl: self = .rtl
            default: return nil
        }
    }
}

/// Method for constraining a resource inside the viewport.
public enum Fit: String, Hashable {
    case cover
    case contain
    case width
    case height
}
