//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// PDF extensions for `Locator.Locations`.
public extension Locator.Locations {
    /// The 1-based page number extracted from a `page=N` fragment parameter,
    /// if present.
    var page: Int? {
        for fragment in fragments {
            let components = fragment.components(separatedBy: CharacterSet(charactersIn: "&#"))
            for component in components {
                let parts = component.components(separatedBy: "=")
                if parts.count == 2, parts[0] == "page", let n = Int(parts[1]) {
                    return n
                }
            }
        }
        return nil
    }
}
