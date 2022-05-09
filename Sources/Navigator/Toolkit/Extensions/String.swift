//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension String {

    /// Same as `index(_,offsetBy:)` but without crashing when reaching the end of the string.
    func clampedIndex(_ i: String.Index, offsetBy n: String.IndexDistance) -> String.Index {
        precondition(n != 0)
        let limit = (n > 0) ? endIndex : startIndex
        guard let index = index(i, offsetBy: n, limitedBy: limit) else {
            return limit
        }
        return index
    }
}
