//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension URL {
    /// Removes the fragment portion of the receiver and returns it.
    mutating func removeFragment() -> String? {
        var fragment: String?
        guard let result = copy({
            fragment = $0.fragment
            $0.fragment = nil
        }) else {
            return nil
        }
        self = result
        return fragment
    }

    /// Creates a copy of the receiver after removing its fragment portion.
    func removingFragment() -> URL? {
        copy { $0.fragment = nil }
    }

    /// Creates a copy of the receiver after modifying its components.
    func copy(_ changes: (inout URLComponents) -> Void) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }
        changes(&components)
        return components.url
    }
}
