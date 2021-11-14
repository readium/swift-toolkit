//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension Array {
    
    @inlinable func appending(_ newElement: Element) -> Self {
        var array = self
        array.append(newElement)
        return array
    }

    @inlinable func appending(contentsOf sequence: Self) -> Self {
        var array = self
        array.append(contentsOf: sequence)
        return array
    }
}
