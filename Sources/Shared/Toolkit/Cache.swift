//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A modern Swift wrapper around `NSCache`, with `Sendable` capabilities.
package final class Cache<Key: AnyObject, Value: AnyObject> {
    let cache: NSCache<Key, Value>

    package init() {
        cache = NSCache()
    }

    /// Clears out the cache.
    package func clear() {
        cache.removeAllObjects()
    }

    package subscript(key: Key) -> Value? {
        get { cache.object(forKey: key) }
        set {
            if let newValue {
                cache.setObject(newValue, forKey: key)
            } else {
                cache.removeObject(forKey: key)
            }
        }
    }
}

/// `NSCache` is naturally thread-safe, but could be used to transfer non-
/// sendable values across isolation domains. So we mark it as `Sendable` only
/// if its types are `Sendable` themselves.
extension Cache: @unchecked Sendable where Key: Sendable, Value: Sendable {}
