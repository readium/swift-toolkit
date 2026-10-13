//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension TimeInterval {
    /// Returns this time in seconds rounded to the nearest millisecond.
    var roundedToMilliseconds: TimeInterval {
        (self * 1000).rounded() / 1000
    }
}
