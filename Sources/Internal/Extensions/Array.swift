//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Array {
    init(builder: (inout Self) -> Void) {
        self.init()
        builder(&self)
    }

    /// Creates a new `Array` from the given `elements`, if they are not nil.
    init(ofNotNil elements: Element?...) {
        self = elements.compactMap { $0 }
    }

    func first<T>(where transform: (Element) throws -> T?) rethrows -> T? {
        for element in self {
            if let result = try transform(element) {
                return result
            }
        }

        return nil
    }

    @inlinable mutating func popFirst() -> Element? {
        if isEmpty {
            return nil
        } else {
            return removeFirst()
        }
    }

    @inlinable func appending(_ newElement: Element) -> Self {
        var array = self
        array.append(newElement)
        return array
    }
}

public extension Array where Element: Equatable {
    @inlinable func containsAny(_ elements: Element...) -> Bool {
        contains { elements.contains($0) }
    }
}

public extension Array where Element: Hashable {
    /// Creates a new `Array` after removing all the element duplicates.
    func removingDuplicates() -> Array {
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

    @inlinable func removing(_ element: Element) -> Self {
        var array = self
        array.removeAll { other in other == element }
        return array
    }

    @inlinable mutating func remove(_ element: Element) {
        removeAll { other in other == element }
    }
}

public extension Array where Element: Equatable {
    func firstMemberFrom(_ candidates: Element?...) -> Element? {
        candidates.compactMap { $0 }.first { contains($0) }
    }
}
