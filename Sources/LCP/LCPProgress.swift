//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Percent-based progress of the acquisition.
public enum LCPProgress {
    /// Undetermined progress, a spinner should be shown to the user.
    case indefinite
    /// A finite progress from 0.0 to 1.0, a progress bar should be shown to the user.
    case percent(Float)
}
