//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An object that can be set aside after use and handed out again later.
protocol Recyclable: AnyObject {
    /// Whether this instance is still fit for reuse.
    ///
    /// It is queried both when the instance is pooled and when it is handed
    /// out again, because an instance may stop being eligible while it sits in
    /// the pool.
    var canBeRecycled: Bool { get }
}

/// A bounded pool of reusable instances.
struct RecyclingPool<Element: Recyclable> {
    /// Maximum number of instances kept around.
    ///
    /// This is a best-effort bound rather than an invariant of the caller:
    /// instances offered beyond it are simply dropped.
    let capacity: Int

    private var elements: [Element] = []

    init(capacity: Int) {
        precondition(capacity >= 0)
        self.capacity = capacity
    }

    var count: Int { elements.count }

    var isEmpty: Bool { elements.isEmpty }

    /// Takes an instance back for later reuse.
    ///
    /// - Returns: Whether the instance was kept. It is rejected when it is not
    ///   reusable, or when the pool is full. A caller holding resources on the
    ///   rejected instance's behalf has to dispose of them itself rather than
    ///   let them go with it.
    @discardableResult
    mutating func push(_ element: Element) -> Bool {
        guard element.canBeRecycled else {
            return false
        }

        // Instances that went stale while pooled are dropped first: they will
        // never be handed out, so letting them take up room would evict usable
        // ones for nothing.
        elements.removeAll { !$0.canBeRecycled }

        guard elements.count < capacity else {
            return false
        }

        elements.append(element)
        return true
    }

    /// Hands out a reusable instance, if there is one.
    ///
    /// Instances that stopped being eligible while pooled are discarded.
    mutating func pop() -> Element? {
        while let element = elements.popLast() {
            if element.canBeRecycled {
                return element
            }
        }

        return nil
    }

    /// Drops every pooled instance.
    mutating func removeAll() {
        elements.removeAll()
    }
}
