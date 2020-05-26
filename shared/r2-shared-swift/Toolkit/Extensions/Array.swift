//
//  Array.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 12/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

extension Array {
    
    /// Creates a new `Array` from the given `element`, if it is not nil. Otherwise creates an
    /// empty array.
    public init(ofNotNil element: Element?) {
        self.init(element.map { [$0] } ?? [])
    }

}

extension Array where Element: Hashable {
    
    /// Creates a new `Array` after removing all the element duplicates.
    public func removingDuplicates() -> Array {
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
