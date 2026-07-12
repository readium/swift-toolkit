//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Array {
    nonisolated func appending(_ newElement: Element) -> Self {
        var array = self
        array.append(newElement)
        return array
    }
}

public extension Array where Element: Hashable {
    /// Creates a new `Array` after removing all the element duplicates.
    nonisolated func removingDuplicates() -> Array {
        var result = Array()
        var added = Set<Element>()
        for element in self {
            if !added.contains(element) {
                result.append(element)
                added.insert(element)
            }
        }
        return result
    }
}
