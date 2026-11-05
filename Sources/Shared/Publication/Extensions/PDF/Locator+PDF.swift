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
    ///
    /// When several fragments or parameters hold a valid page number, the
    /// first one wins.
    var page: Int? {
        fragments
            .lazy
            .flatMap { $0.parameters(named: "page") }
            .compactMap { Int($0) }
            .first
    }
}
