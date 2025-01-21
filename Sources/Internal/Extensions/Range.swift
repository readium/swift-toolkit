//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Range where Bound == UInt64 {
    func clampedToInt() -> Range<UInt64> {
        clamped(to: 0 ..< UInt64(Int.max))
    }
}
