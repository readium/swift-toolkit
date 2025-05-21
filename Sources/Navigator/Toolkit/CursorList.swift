//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A `List` with a mutable cursor index.
struct CursorList<Element> {
    private let list: [Element]
    private let startIndex: Int

    init(list: [Element] = [], startIndex: Int = 0) {
        self.list = list
        self.startIndex = startIndex
    }

    private var index: Int?

    /// Returns the current element.
    mutating func current() -> Element? {
        moveAndGet(index ?? startIndex)
    }

    /// Moves the cursor backward and returns the element, or null when reaching the beginning.
    mutating func previous() -> Element? {
        moveAndGet(index.map { $0 - 1 } ?? startIndex)
    }

    /// Moves the cursor forward and returns the element, or null when reaching the end.
    mutating func next() -> Element? {
        moveAndGet(index.map { $0 + 1 } ?? startIndex)
    }

    private mutating func moveAndGet(_ index: Int) -> Element? {
        guard list.indices.contains(index) else {
            return nil
        }
        self.index = index
        return list[index]
    }
}
