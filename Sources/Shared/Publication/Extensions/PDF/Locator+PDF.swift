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
            .compactMap { URLFragment(percentDecoded: $0) }
            .flatMap { $0.parameters(named: "page") }
            .compactMap { Int($0) }
            .first
    }
}

/// PDF extensions for `URLFragment`.
public extension URLFragment {
    /// Creates a `page=N` fragment targeting the page with the given 1-based
    /// `number` in a PDF document.
    ///
    /// - https://www.rfc-editor.org/rfc/rfc8118#section-3
    static func page(_ number: Int) -> URLFragment {
        URLFragment(rawValue: "page=\(number)")!
    }
}
