//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension Array {

    /// Creates a new `Array` from the given `element`, if it is not nil. Otherwise creates an
    /// empty array.
    public init(ofNotNil element: Element?) {
        self.init(element.map { [$0] } ?? [])
    }

    public func first<T>(where transform: (Element) throws -> T?) rethrows -> T? {
        for element in self {
            if let result = try transform(element) {
                return result
            }
        }

        return nil
    }

    @inlinable public mutating func popFirst() -> Element? {
        if isEmpty {
            return nil
        } else {
            return removeFirst()
        }
    }

    @inlinable public func appending(_ newElement: Element) -> Self {
        var array = self
        array.append(newElement)
        return array
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

    @inlinable public func removing(_ element: Element) -> Self {
        var array = self
        array.removeAll { other in other == element }
        return array
    }
}

extension Array where Element: Equatable {

    public func firstMemberFrom(_ candidates: Element?...) -> Element? {
        candidates.compactMap { $0 }.first { contains($0) }
    }
}