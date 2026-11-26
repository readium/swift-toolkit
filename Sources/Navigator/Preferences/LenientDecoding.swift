//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Helpers to decode the preferences persisted with Readium 3.x, where an
/// invalid value drops only its preference.
extension KeyedDecodingContainer {
    /// Decodes the value for `key`, or returns `nil` if it is missing or
    /// invalid.
    func decodeLeniently<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        try? decodeIfPresent(type, forKey: key)
    }
}
